# Resolving Imports

WSDL documents often reference external schemas through imports and includes. This guide explains how the library resolves these references and the security controls in place.

## Location Types

The library handles three types of locations:

| Type | Example | Resolution |
|------|---------|------------|
| HTTP/HTTPS URL | `http://example.com/schema.xsd` | Fetched via HTTP GET |
| Absolute file path | `/path/to/schema.xsd` | Read from filesystem (with sandbox restrictions) |
| Raw XML | `<schema>...</schema>` | Used as-is |

## Relative Path Resolution

Relative paths in `schemaLocation` attributes are resolved against the parent document's location.

### From a File

``` ruby
# WSDL loaded from: /app/wsdl/service.wsdl
# Schema import:    schemaLocation="./types.xsd"
# Resolved to:      /app/wsdl/types.xsd

client = WSDL::Client.new('/app/wsdl/service.wsdl')
```

### From a URL

``` ruby
# WSDL loaded from: http://example.com/wsdl/service.wsdl
# Schema import:    schemaLocation="../schemas/types.xsd"
# Resolved to:      http://example.com/schemas/types.xsd

client = WSDL::Client.new('http://example.com/wsdl/service.wsdl')
```

### From a Relative Path

When loading from a relative path, it's first expanded against the current working directory:

``` ruby
# Current directory: /app
# WSDL path:         wsdl/service.wsdl
# Expanded to:       /app/wsdl/service.wsdl

client = WSDL::Client.new('wsdl/service.wsdl')
```

## XSD Imports vs Includes

The library supports both `<xs:import>` and `<xs:include>`:

| Directive | Purpose | Namespace |
|-----------|---------|-----------|
| `xs:import` | Reference types from a different namespace | Different from parent |
| `xs:include` | Merge definitions into the current schema | Same as parent |

Both support relative `schemaLocation` attributes.

## Security Restrictions

The library implements security controls to prevent path traversal attacks, where malicious `schemaLocation` attributes could read arbitrary system files.

### How Path Traversal Attacks Work

A malicious WSDL could contain:

``` xml
<xs:import schemaLocation="../../../../../../../../etc/passwd"/>
```

Without protection, this would resolve to `/etc/passwd` and expose sensitive system files.

### Default Security Behavior

By default, the library automatically determines file access based on the WSDL source:

| WSDL Source | File Access | Reason |
|-------------|-------------|--------|
| **URL** (`http://...`) | Disabled | All imports must use URLs |
| **File path** | Sandboxed | Restricted to WSDL's parent directory |
| **Inline XML** | Disabled | No base path to sandbox against |

This means:

- **URL-loaded WSDLs** cannot read local files at all — this is the primary security control
- **File-loaded WSDLs** can only read files within the WSDL's parent directory — prevents path traversal
- **Inline XML** cannot have relative file imports

The rationale: even locally-stored WSDLs could be downloaded from untrusted sources, so sandboxing to the parent directory provides defense-in-depth against path traversal attacks while still allowing typical relative imports within the same directory.

### Example: URL-Loaded WSDL

``` ruby
# Loading from URL: file access is completely disabled
client = WSDL::Client.new('http://example.com/service?wsdl')

# If the WSDL contains: schemaLocation="../schemas/types.xsd"
# This resolves to: http://example.com/schemas/types.xsd (URL, allowed)

# If the WSDL contains: schemaLocation="/etc/passwd"
# This raises: WSDL::PathRestrictionError (file access disabled)
```

### Example: File-Loaded WSDL

``` ruby
# Loading from file: sandboxed to parent directory
client = WSDL::Client.new('/app/wsdl/service.wsdl')

# Imports within the same directory work:
# ./types.xsd → /app/wsdl/types.xsd (allowed)
# subdirectory/schema.xsd → /app/wsdl/subdirectory/schema.xsd (allowed)

# Imports to sibling directories are blocked:
# ../schemas/types.xsd → /app/schemas/types.xsd (blocked - outside sandbox)
```

### Expanding the Sandbox

If your WSDL imports schemas from sibling directories, use the `sandbox_paths` option:

``` ruby
# Allow access to multiple directories
client = WSDL::Client.new('/app/wsdl/service.wsdl',
                          sandbox_paths: ['/app/wsdl', '/app/schemas', '/app/common'])

# Now these imports work:
# ../schemas/types.xsd → /app/schemas/types.xsd (allowed)
# ../common/base.xsd → /app/common/base.xsd (allowed)
```

## Schema Import Failure Policy

Use `schema_imports` to control non-security schema import failures:

``` ruby
# Default: log and skip non-security schema import failures
client = WSDL::Client.new('/app/wsdl/service.wsdl', schema_imports: :best_effort)

# Strict: raise non-security schema import failures
client = WSDL::Client.new('/app/wsdl/service.wsdl', schema_imports: :strict)
```

`schema_imports: :best_effort` is the default because many real-world enterprise
WSDLs contain optional or vendor-specific schema references that are unreachable
in normal environments. Best-effort mode keeps parsing resilient while still
failing closed on fatal security/safety errors.

Security violations are always fatal regardless of this setting:

- `WSDL::PathRestrictionError` (sandbox/file access violations)
- `WSDL::UnresolvableImportError` (relative imports with inline XML base)
- `WSDL::XMLSecurityError` (DOCTYPE/entity-related XML security violations)
- `WSDL::ResourceLimitError` (configured safety limits exceeded)

### Blocked Patterns

The following are always blocked regardless of settings:

- `file://` URLs — Use file paths instead if you need local files
- File access when the WSDL is loaded from a URL
- Path traversal that escapes the sandbox (e.g., `../../../../etc/passwd`)

## Inline XML Limitations

When loading a WSDL from a raw XML string, relative imports cannot be resolved:

``` ruby
xml = '<definitions>...</definitions>'
client = WSDL::Client.new(xml)
# If the WSDL contains relative imports, raises:
# WSDL::UnresolvableImportError: Cannot resolve relative path "types.xsd":
# base is inline XML. When loading WSDL from a string, all schema imports
# must use absolute URLs.
```

**Solutions:**

1. Load the WSDL from a file path instead of a string
2. Ensure all schema imports use absolute URLs
3. Pre-process the XML to inline the schemas

## Error Messages

### PathRestrictionError

Raised when file access is blocked:

``` ruby
# When file access is disabled (URL-loaded WSDL)
WSDL::PathRestrictionError: File access is disabled. Cannot read "/path/to/schema.xsd".
All schema imports must use URLs, or provide sandbox_paths to allow file access.

# When path is outside sandbox
WSDL::PathRestrictionError: Path "/etc/passwd" is outside the allowed directories.
Allowed: ["/app/wsdl"]. This may indicate a path traversal attack in a schemaLocation attribute.

# When file:// URL is used
WSDL::PathRestrictionError: file:// URLs are not allowed for security reasons: "file:///etc/passwd".
Use a local file path instead if you need to load from the filesystem.
```

`PathRestrictionError` is always raised and is never downgraded to a warning.

### UnresolvableImportError

Raised for inline XML with relative imports:

``` ruby
WSDL::UnresolvableImportError: Cannot resolve relative path "types.xsd": base is inline XML.
When loading WSDL from a string, all schema imports must use absolute URLs.
```

## Troubleshooting

### Enable Import Logging

``` ruby
require 'logging'

logger = Logging.logger['WSDL::Parser::Importer']
logger.add_appenders(Logging.appenders.stdout)
logger.level = :debug

client = WSDL::Client.new('http://example.com/service?wsdl')
# Logs each import/include resolution
```

### Common Errors

**PathRestrictionError: File access is disabled**

- Cause: WSDL was loaded from URL but has file-based schema imports
- Fix: Ensure all schema imports use HTTP/HTTPS URLs

**PathRestrictionError: Path is outside the allowed directories**

- Cause: Schema import attempts to access files outside the sandbox
- Fix: Either the import path is malicious, or you need to expand `sandbox_paths`

**UnresolvableImportError: base is inline XML**

- Cause: WSDL was loaded from inline XML with relative schema references
- Fix: Load from file path or use absolute URLs

**SchemaImportError**

A non-fatal schema import failed and was wrapped as `WSDL::SchemaImportError`.
In `schema_imports: :strict` mode this is raised. In `:best_effort` mode it is
logged and skipped.

Common root causes:
- The relative path in the WSDL is incorrect
- The schema file exists at the expected location
- File permissions allow reading

**Schema not found for namespace**

The schema was not imported. Possible causes:
- Import failed and was skipped in `schema_imports: :best_effort` mode (check logs)
- Namespace mismatch between import and schema
- Path was blocked by security restrictions (`PathRestrictionError` is raised)

## Security Best Practices

1. **Use URLs for remote WSDLs** — When loading WSDLs from external sources, always use HTTP/HTTPS URLs so that file access is automatically disabled.

2. **Use explicit sandbox_paths for multi-directory imports** — If your WSDL imports schemas from sibling directories, specify explicit sandbox paths:
   ```ruby
   client = WSDL::Client.new('/app/wsdl/service.wsdl',
                             sandbox_paths: ['/app/wsdl', '/app/schemas', '/app/common'])
   ```

3. **Minimize sandbox scope** — Only include the directories that are actually needed.

4. **Review import logs** — Enable debug logging when testing new WSDLs to see all import resolutions.

5. **Validate WSDL sources** — Don't load WSDLs from untrusted sources without understanding the security implications.
