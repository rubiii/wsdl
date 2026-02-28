# Getting Started

## Installation

Install the gem from RubyGems:

```
$ gem install wsdl
```

Or add it to your Gemfile:

``` ruby
gem 'wsdl'
```

Then run `bundle install`.

## Requirements

- Ruby 3.2 or higher

## Loading a WSDL Document

The `WSDL` class accepts WSDL documents from various sources:

### From a URL

``` ruby
require 'wsdl'

client = WSDL.new('http://example.com/service?wsdl')
```

### From a Local File

``` ruby
client = WSDL.new('/path/to/service.wsdl')
```

### From a Raw XML String

``` ruby
xml = File.read('/path/to/service.wsdl')
client = WSDL.new(xml)
```

## Basic Workflow

Once you've loaded a WSDL document, the typical workflow is:

### 1. Discover Services and Ports

``` ruby
client.services
# => {
#   'MyService' => {
#     ports: {
#       'MyServicePort' => {
#         type: 'http://schemas.xmlsoap.org/wsdl/soap/',
#         location: 'http://example.com/service'
#       }
#     }
#   }
# }
```

### 2. List Available Operations

``` ruby
client.operations('MyService', 'MyServicePort')
# => ['GetUser', 'CreateUser', 'UpdateUser', 'DeleteUser']
```

### 3. Get an Operation

``` ruby
operation = client.operation('MyService', 'MyServicePort', 'GetUser')
```

### 4. Inspect the Expected Request Structure

``` ruby
operation.example_body
# => { GetUser: { userId: 'int' } }

operation.example_header
# => { AuthToken: { token: 'string' } }
```

### 5. Set the Request Body and Call

``` ruby
operation.body = {
  GetUser: {
    userId: 123
  }
}

response = operation.call
```

### 6. Handle the Response

``` ruby
response.body    # Parsed response as a Hash
response.raw     # Raw XML string
response.doc     # Nokogiri XML document
```

## Next Steps

- [Inspecting Services](inspecting-services.md) - Learn more about exploring WSDL structure
- [Building Requests](building-requests.md) - Detailed guide on constructing requests
- [Handling Responses](handling-responses.md) - Working with SOAP responses
- [Configuration](configuration.md) - Customizing HTTP adapters and other options