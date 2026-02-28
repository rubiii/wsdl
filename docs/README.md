# Documentation

## Table of Contents

- [Getting Started](getting-started.md)
- [Inspecting Services](inspecting-services.md)
- [Building Requests](building-requests.md)
- [Handling Responses](handling-responses.md)
- [Configuration](configuration.md)

## Overview

WSDL is a Ruby library for parsing WSDL documents and interacting with SOAP services. It allows you to:

- Load WSDL documents from URLs, local files, or raw XML
- Inspect services, ports, and operations
- Generate example request bodies from schema definitions
- Build and send SOAP requests
- Parse SOAP responses

## Quick Reference

```ruby
require 'wsdl'

# Load WSDL
client = WSDL.new('http://example.com/service?wsdl')

# Inspect
client.services                                    # List all services
client.operations('ServiceName', 'PortName')       # List operations

# Build and call
op = client.operation('ServiceName', 'PortName', 'OperationName')
op.example_body                                    # See expected structure
op.body = { ... }                                  # Set request body
response = op.call                                 # Make the call
```

## Support

- [GitHub Issues](https://github.com/rubiii/wsdl/issues)