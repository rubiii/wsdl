# frozen_string_literal: true

RSpec.describe WSDL::Parser::OperationMap do
  let(:map) { described_class.new }

  # Simple test double that responds to input_name
  def operation(input_name: nil)
    instance_double(WSDL::Parser::PortTypeOperation, input_name:)
  end

  describe '#add and #keys' do
    it 'stores operations by name' do
      map.add('getUser', operation)
      expect(map.keys).to eq(['getUser'])
    end

    it 'stores multiple operations with different names' do
      map.add('getUser', operation)
      map.add('deleteUser', operation)
      expect(map.keys).to contain_exactly('getUser', 'deleteUser')
    end

    it 'stores multiple operations with the same name' do
      map.add('Lookup', operation(input_name: 'ById'))
      map.add('Lookup', operation(input_name: 'ByName'))
      expect(map.keys).to eq(['Lookup'])
    end
  end

  describe '#include?' do
    it 'returns true for existing names' do
      map.add('getUser', operation)
      expect(map.include?('getUser')).to be true
    end

    it 'returns false for non-existing names' do
      expect(map.include?('getUser')).to be false
    end
  end

  describe '#fetch' do
    context 'with a single operation' do
      before do
        map.add('getUser', operation(input_name: 'getUser'))
      end

      it 'returns the operation directly' do
        expect(map.fetch('getUser').input_name).to eq('getUser')
      end

      it 'ignores input_name when not overloaded' do
        expect(map.fetch('getUser', input_name: 'anything').input_name).to eq('getUser')
      end
    end

    context 'with overloaded operations' do
      let(:by_id) { operation(input_name: 'LookupById') }
      let(:by_name) { operation(input_name: 'LookupByName') }

      before do
        map.add('Lookup', by_id)
        map.add('Lookup', by_name)
      end

      it 'resolves by input_name' do
        expect(map.fetch('Lookup', input_name: 'LookupById')).to eq(by_id)
        expect(map.fetch('Lookup', input_name: 'LookupByName')).to eq(by_name)
      end

      it 'accepts symbol input_name' do
        expect(map.fetch('Lookup', input_name: :LookupById)).to eq(by_id)
      end

      it 'raises ArgumentError without input_name' do
        expect { map.fetch('Lookup') }
          .to raise_error(ArgumentError, /overloaded.*Provide input_name.*LookupById.*LookupByName/)
      end

      it 'raises ArgumentError for unknown input_name' do
        expect { map.fetch('Lookup', input_name: 'Unknown') }
          .to raise_error(ArgumentError, /No overload.*Unknown/)
      end
    end

    context 'when name is not found' do
      it 'raises KeyError by default' do
        expect { map.fetch('missing') }.to raise_error(KeyError)
      end

      it 'yields the not-found block' do
        result = map.fetch('missing') { 'fallback' } # rubocop:disable Style/RedundantFetchBlock -- testing block behavior
        expect(result).to eq('fallback')
      end
    end
  end

  describe '#overloaded_name?' do
    it 'returns false for single operations' do
      map.add('getUser', operation)
      expect(map.overloaded_name?('getUser')).to be false
    end

    it 'returns true for overloaded operations' do
      map.add('Lookup', operation(input_name: 'A'))
      map.add('Lookup', operation(input_name: 'B'))
      expect(map.overloaded_name?('Lookup')).to be true
    end

    it 'returns false for non-existing names' do
      expect(map.overloaded_name?('missing')).to be false
    end
  end

  describe '#overload_count' do
    it 'returns 0 for non-existing names' do
      expect(map.overload_count('missing')).to eq(0)
    end

    it 'returns 1 for single operations' do
      map.add('getUser', operation)
      expect(map.overload_count('getUser')).to eq(1)
    end

    it 'returns the count for overloaded operations' do
      map.add('Lookup', operation(input_name: 'A'))
      map.add('Lookup', operation(input_name: 'B'))
      map.add('Lookup', operation(input_name: 'C'))
      expect(map.overload_count('Lookup')).to eq(3)
    end
  end

  describe '#to_a' do
    it 'returns an empty array for an empty map' do
      expect(map.to_a).to eq([])
    end

    it 'returns hashes without input_name for non-overloaded operations' do
      map.add('getUser', operation)
      map.add('deleteUser', operation)

      expect(map.to_a).to eq([
        { name: 'getUser' },
        { name: 'deleteUser' }
      ])
    end

    it 'returns hashes with input_name for overloaded operations' do
      map.add('Lookup', operation(input_name: 'LookupById'))
      map.add('Lookup', operation(input_name: 'LookupByName'))

      expect(map.to_a).to eq([
        { name: 'Lookup', input_name: 'LookupById' },
        { name: 'Lookup', input_name: 'LookupByName' }
      ])
    end

    it 'handles a mix of non-overloaded and overloaded operations' do
      map.add('getUser', operation)
      map.add('Lookup', operation(input_name: 'LookupById'))
      map.add('Lookup', operation(input_name: 'LookupByName'))

      expect(map.to_a).to eq([
        { name: 'getUser' },
        { name: 'Lookup', input_name: 'LookupById' },
        { name: 'Lookup', input_name: 'LookupByName' }
      ])
    end
  end
end
