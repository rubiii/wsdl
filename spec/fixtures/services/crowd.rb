# frozen_string_literal: true

WSDL::TestService.define(:crowd, wsdl: 'wsdl/crowd') do
  operation :findGroupByName do
    on in1: 'developers' do
      {
        out: {
          ID: 1001,
          active: true,
          attributes: {
            SOAPAttribute: [
              { name: 'description', values: { string: ['Engineering team'] } },
              { name: 'type', values: { string: %w[internal ldap] } }
            ]
          },
          conception: '2020-03-15T10:00:00Z',
          description: 'Software developers',
          directoryId: 42,
          lastModified: '2025-01-10T14:30:00Z',
          members: { string: %w[alice bob charlie] },
          name: 'developers'
        }
      }
    end

    on in1: 'nonexistent' do
      {
        out: {
          ID: 0,
          active: false,
          conception: '1970-01-01T00:00:00Z',
          description: '',
          directoryId: 0,
          lastModified: '1970-01-01T00:00:00Z',
          name: ''
        }
      }
    end
  end
end
