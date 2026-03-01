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
# Schema import:    schemaLocation="../schemas/types.xsd"
# Resolved to:      /app/schemas/types.xsd

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

By default, the library uses **automatic mode** (`file_access: :auto`) which applies different restrictions based on the WSDL source:

| WSDL Source | File Access | Reason |
|-------------|-------------|--------|
| **URL** (`http://...`) | Disabled | All imports must use URLs |
| **File path** | Unrestricted | Local files are trusted |
| **Inline XML** | Disabled | No base path to sandbox against |

This means:

- **URL-loaded WSDLs** cannot read local files at all — this is the primary security control
- **File-loaded WSDLs** can read any local files — the user controls the WSDL source
- **Inline XML** cannot have relative file imports

The rationale: if you're loading a WSDL from your own filesystem, you presumably trust its contents. The main security concern is URL-loaded or inline WSDLs that could be attacker-controlled.

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
# Loading from file: unrestricted (trusts local files)
client = WSDL::Client.new('/app/wsdl/service.wsdl')

# All relative imports work, including sibling directories:
# ../schemas/types.xsd → /app/schemas/types.xsd (allowed)
# ../common/base.xsd → /app/common/base.xsd (allowed)

# If you need stricter controls, use explicit sandbox mode:
client = WSDL::Client.new('/app/wsdl/service.wsdl',
                          file_access: :sandbox,
                          sandbox_paths: ['/app/wsdl', '/app/schemas'])
```

### Configuring File Access

You can customize file access behavior:

``` ruby
# Disable file access entirely (URL-only mode)
client = WSDL::Client.new('/path/to/service.wsdl', file_access: :disabled)

# Allow access to specific directories (sandbox_paths is required with :sandbox)
client = WSDL::Client.new('/path/to/service.wsdl',
                          file_access: :sandbox,
                          sandbox_paths: ['/path/to', '/shared/schemas'])

# Unrestricted (not recommended for untrusted WSDLs)
client = WSDL::Client.new('/path/to/service.wsdl', file_access: :unrestricted)
```

**Note:** Invalid options are validated immediately on initialization:

``` ruby
# Invalid file_access mode raises ArgumentError
WSDL::Client.new('service.wsdl', file_access: :invalid)
# => ArgumentError: Invalid file_access mode: :invalid. Valid modes are: :sandbox, :disabled, :unrestricted

# :sandbox mode without sandbox_paths raises ArgumentError
WSDL::Client.new('service.wsdl', file_access: :sandbox)
# => ArgumentError: file_access: :sandbox requires sandbox_paths to be specified.
```

### File Access Options

| Option | Description | Use Case |
|--------|-------------|----------|
| `:auto` | Automatic based on source (default) | Most applications |
| `:sandbox` | Allow only specified directories | High-security environments |
| `:disabled` | No file access at all | URL-only mode |
| `:unrestricted` | No restrictions | Explicit trust (same as auto for files) |

### Blocked Patterns

The following are always blocked regardless of settings:

- `file://` URLs — Use file paths instead if you need local files
- File access when the WSDL is loaded from a URL (in `:auto` mode)

When using `:sandbox` mode, path traversal that escapes the sandbox is also blocked (e.g., `../../../../etc/passwd`).

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
# When file access is disabled
WSDL::PathRestrictionError: File access is disabled (mode: :disabled). Cannot read "/path/to/schema.xsd".
All schema imports must use URLs, or use file_access: :sandbox with explicit sandbox_paths.

# When path is outside sandbox
WSDL::PathRestrictionError: Path "/etc/passwd" is outside the allowed directories.
Allowed: ["/app/wsdl"]. This may indicate a path traversal attack in a schemaLocation attribute.

# When file:// URL is used
WSDL::PathRestrictionError: file:// URLs are not allowed for security reasons: "file:///etc/passwd".
Use a local file path instead if you need to load from the filesystem.
```

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

**PathRestrictionError: File access is disabled (mode: :disabled)**

- Cause: WSDL was loaded from URL but has file-based schema imports
- Fix: Ensure all schema imports use HTTP/HTTPS URLs, or use `file_access: :sandbox` with explicit `sandbox_paths`

**PathRestrictionError: Path is outside the allowed directories**

- Cause: Schema import attempts to access files outside the sandbox
- Fix: Either the import path is malicious, or you need to expand `sandbox_paths`

**UnresolvableImportError: base is inline XML**

- Cause: WSDL was loaded from inline XML with relative schema references
- Fix: Load from file path or use absolute URLs

**Errno::ENOENT (No such file or directory)**

The resolved path doesn't exist. Check:
- The relative path in the WSDL is correct
- The schema file exists at the expected location
- File permissions allow reading

**Schema not found for namespace**

The schema was not imported. Possible causes:
- Import failed silently (check logs)
- Namespace mismatch between import and schema
- Path was blocked by security restrictions (check for PathRestrictionError in logs)

## Security Best Practices

1. **Use URLs for remote WSDLs** — When loading WSDLs from external sources, always use HTTP/HTTPS URLs so that file access is automatically disabled.

2. **Use `:sandbox` for untrusted local files** — If you're loading a WSDL from a location where the content might be attacker-controlled, use explicit sandbox mode:
   ```ruby
   client = WSDL::Client.new(untrusted_path,
                             file_access: :sandbox,
                             sandbox_paths: [File.dirname(untrusted_path)])
   ```

3. **Minimize sandbox scope** — When using `:sandbox`, only include the directories that are actually needed.

4. **Review import logs** — Enable debug logging when testing new WSDLs to see all import resolutions.

5. **Validate WSDL sources** — Don't load WSDLs from untrusted sources without understanding the security implications.