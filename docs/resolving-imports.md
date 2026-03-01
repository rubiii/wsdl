# Resolving Imports

WSDL documents often reference external schemas through imports and includes. This guide explains how the library resolves these references.

## Location Types

The library handles three types of locations:

| Type | Example | Resolution |
|------|---------|------------|
| HTTP/HTTPS URL | `http://example.com/schema.xsd` | Fetched via HTTP GET |
| Absolute file path | `/path/to/schema.xsd` | Read from filesystem |
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

**UnresolvableImportError**

Occurs when a relative import cannot be resolved. Usually means:
- WSDL was loaded from inline XML with relative schema references
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