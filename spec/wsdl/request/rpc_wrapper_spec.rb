# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Request::RPCWrapper do
  subject(:wrapper) do
    described_class.new(
      operation_name: 'doSomething',
      namespace_uri: 'http://example.com/api'
    )
  end

  def build_document(body_nodes: [], header_nodes: [], namespace_decls: [])
    doc = WSDL::Request::AST.new
    doc.body.concat(body_nodes)
    doc.header.concat(header_nodes)
    doc.namespace_decls.concat(namespace_decls)
    doc
  end

  def build_node(name, namespace_uri: nil)
    WSDL::Request::Node.new(
      name: name,
      prefix: nil,
      local_name: name,
      namespace_uri: namespace_uri
    )
  end

  describe '#wrap' do
    it 'wraps body nodes in an RPC wrapper element' do
      node = build_node('param1')
      document = build_document(body_nodes: [node])

      result = wrapper.wrap(document)

      expect(result.body.length).to eq(1)
      rpc_element = result.body.first
      expect(rpc_element.local_name).to eq('doSomething')
      expect(rpc_element.namespace_uri).to eq('http://example.com/api')
      expect(rpc_element.children).to eq([node])
    end

    it 'preserves header nodes' do
      header_node = build_node('AuthHeader')
      body_node = build_node('param1')
      document = build_document(header_nodes: [header_node], body_nodes: [body_node])

      result = wrapper.wrap(document)

      expect(result.header).to eq([header_node])
    end

    it 'preserves namespace declarations' do
      decl = WSDL::Request::NamespaceDecl.new(prefix: 'ns0', uri: 'http://example.com/api')
      body_node = build_node('param1')
      document = build_document(namespace_decls: [decl], body_nodes: [body_node])

      result = wrapper.wrap(document)

      expect(result.namespace_decls).to eq([decl])
    end

    it 'returns the document unchanged when body is empty' do
      document = build_document

      result = wrapper.wrap(document)

      expect(result).to be(document)
    end

    it 'returns the document unchanged when already wrapped' do
      rpc_node = build_node('doSomething')
      document = build_document(body_nodes: [rpc_node])

      result = wrapper.wrap(document)

      expect(result).to be(document)
    end

    it 'wraps when the single body node has a different name' do
      node = build_node('notTheOperationName')
      document = build_document(body_nodes: [node])

      result = wrapper.wrap(document)

      expect(result.body.first.local_name).to eq('doSomething')
      expect(result.body.first.children).to eq([node])
    end

    it 'wraps multiple body nodes' do
      nodes = [build_node('param1'), build_node('param2')]
      document = build_document(body_nodes: nodes)

      result = wrapper.wrap(document)

      expect(result.body.length).to eq(1)
      expect(result.body.first.children).to eq(nodes)
    end

    context 'with nil namespace_uri' do
      subject(:wrapper) do
        described_class.new(operation_name: 'op3', namespace_uri: nil)
      end

      it 'creates an unqualified wrapper element' do
        node = build_node('param1')
        document = build_document(body_nodes: [node])

        result = wrapper.wrap(document)

        expect(result.body.first.namespace_uri).to be_nil
        expect(result.body.first.local_name).to eq('op3')
      end
    end
  end
end
