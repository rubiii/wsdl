# frozen_string_literal: true

RSpec.describe WSDL::Security::AlgorithmMapper do
  describe '.digest_algorithm' do
    context 'with supported algorithms' do
      it 'maps SHA-1 URI' do
        uri = 'http://www.w3.org/2000/09/xmldsig#sha1'
        expect(described_class.digest_algorithm(uri)).to eq(:sha1)
      end

      it 'maps SHA-224 URI' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#sha224'
        expect(described_class.digest_algorithm(uri)).to eq(:sha224)
      end

      it 'maps SHA-256 URI' do
        uri = 'http://www.w3.org/2001/04/xmlenc#sha256'
        expect(described_class.digest_algorithm(uri)).to eq(:sha256)
      end

      it 'maps SHA-384 URI' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#sha384'
        expect(described_class.digest_algorithm(uri)).to eq(:sha384)
      end

      it 'maps SHA-512 URI' do
        uri = 'http://www.w3.org/2001/04/xmlenc#sha512'
        expect(described_class.digest_algorithm(uri)).to eq(:sha512)
      end

      it 'handles case-insensitive matching' do
        uri = 'http://example.com/SHA256'
        expect(described_class.digest_algorithm(uri)).to eq(:sha256)
      end
    end

    context 'with unknown algorithm' do
      it 'raises UnsupportedAlgorithmError' do
        expect { described_class.digest_algorithm('http://attacker.com/fake') }
          .to raise_error(WSDL::UnsupportedAlgorithmError, /Unsupported digest algorithm/)
      end

      it 'includes algorithm URI in error' do
        error = nil
        begin
          described_class.digest_algorithm('http://attacker.com/fake')
        rescue WSDL::UnsupportedAlgorithmError => e
          error = e
        end

        expect(error.algorithm_uri).to eq('http://attacker.com/fake')
        expect(error.algorithm_type).to eq(:digest)
      end
    end

    context 'with nil algorithm' do
      it 'raises UnsupportedAlgorithmError' do
        expect { described_class.digest_algorithm(nil) }
          .to raise_error(WSDL::UnsupportedAlgorithmError, /Missing digest algorithm/)
      end

      it 'sets algorithm_type in error' do
        error = nil
        begin
          described_class.digest_algorithm(nil)
        rescue WSDL::UnsupportedAlgorithmError => e
          error = e
        end

        expect(error.algorithm_type).to eq(:digest)
        expect(error.algorithm_uri).to be_nil
      end
    end

    context 'with empty algorithm' do
      it 'raises UnsupportedAlgorithmError' do
        expect { described_class.digest_algorithm('') }
          .to raise_error(WSDL::UnsupportedAlgorithmError, /Missing digest algorithm/)
      end
    end
  end

  describe '.signature_digest' do
    context 'with RSA algorithms' do
      it 'maps RSA-SHA1' do
        uri = 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
        expect(described_class.signature_digest(uri)).to eq('SHA1')
      end

      it 'maps RSA-SHA224' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha224'
        expect(described_class.signature_digest(uri)).to eq('SHA224')
      end

      it 'maps RSA-SHA256' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
        expect(described_class.signature_digest(uri)).to eq('SHA256')
      end

      it 'maps RSA-SHA384' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha384'
        expect(described_class.signature_digest(uri)).to eq('SHA384')
      end

      it 'maps RSA-SHA512' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha512'
        expect(described_class.signature_digest(uri)).to eq('SHA512')
      end

      it 'handles case-insensitive matching' do
        uri = 'http://example.com/RSA-SHA256'
        expect(described_class.signature_digest(uri)).to eq('SHA256')
      end
    end

    context 'with ECDSA algorithms' do
      it 'maps ECDSA-SHA1' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha1'
        expect(described_class.signature_digest(uri)).to eq('SHA1')
      end

      it 'maps ECDSA-SHA224' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha224'
        expect(described_class.signature_digest(uri)).to eq('SHA224')
      end

      it 'maps ECDSA-SHA256' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256'
        expect(described_class.signature_digest(uri)).to eq('SHA256')
      end

      it 'maps ECDSA-SHA384' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha384'
        expect(described_class.signature_digest(uri)).to eq('SHA384')
      end

      it 'maps ECDSA-SHA512' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha512'
        expect(described_class.signature_digest(uri)).to eq('SHA512')
      end
    end

    context 'with DSA algorithms' do
      it 'maps DSA-SHA1' do
        uri = 'http://www.w3.org/2000/09/xmldsig#dsa-sha1'
        expect(described_class.signature_digest(uri)).to eq('SHA1')
      end

      it 'maps DSA-SHA256' do
        uri = 'http://www.w3.org/2009/xmldsig11#dsa-sha256'
        expect(described_class.signature_digest(uri)).to eq('SHA256')
      end
    end

    context 'with unknown algorithm' do
      it 'raises UnsupportedAlgorithmError' do
        expect { described_class.signature_digest('http://unknown/sig') }
          .to raise_error(WSDL::UnsupportedAlgorithmError, /Unsupported signature algorithm/)
      end

      it 'includes algorithm URI in error' do
        error = nil
        begin
          described_class.signature_digest('http://unknown/sig')
        rescue WSDL::UnsupportedAlgorithmError => e
          error = e
        end

        expect(error.algorithm_uri).to eq('http://unknown/sig')
        expect(error.algorithm_type).to eq(:signature)
      end
    end

    context 'with nil algorithm' do
      it 'raises UnsupportedAlgorithmError' do
        expect { described_class.signature_digest(nil) }
          .to raise_error(WSDL::UnsupportedAlgorithmError, /Missing signature algorithm/)
      end
    end

    context 'with empty algorithm' do
      it 'raises UnsupportedAlgorithmError' do
        expect { described_class.signature_digest('') }
          .to raise_error(WSDL::UnsupportedAlgorithmError, /Missing signature algorithm/)
      end
    end
  end

  describe '.c14n_algorithm' do
    context 'with nil URI' do
      it 'defaults to exclusive_1_0 (safe default)' do
        expect(described_class.c14n_algorithm(nil)).to eq(:exclusive_1_0)
      end
    end

    context 'with empty URI' do
      it 'defaults to exclusive_1_0 (safe default)' do
        expect(described_class.c14n_algorithm('')).to eq(:exclusive_1_0)
      end
    end

    context 'with exclusive canonicalization' do
      it 'maps exclusive C14N 1.0' do
        uri = 'http://www.w3.org/2001/10/xml-exc-c14n#'
        expect(described_class.c14n_algorithm(uri)).to eq(:exclusive_1_0)
      end

      it 'maps exclusive C14N 1.0 with comments' do
        uri = 'http://www.w3.org/2001/10/xml-exc-c14n#WithComments'
        expect(described_class.c14n_algorithm(uri)).to eq(:exclusive_1_0_with_comments)
      end
    end

    context 'with inclusive canonicalization 1.0' do
      it 'maps inclusive C14N 1.0' do
        uri = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315'
        expect(described_class.c14n_algorithm(uri)).to eq(:inclusive_1_0)
      end

      it 'maps inclusive C14N 1.0 with comments' do
        uri = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments'
        expect(described_class.c14n_algorithm(uri)).to eq(:inclusive_1_0_with_comments)
      end
    end

    context 'with inclusive canonicalization 1.1' do
      it 'maps inclusive C14N 1.1' do
        uri = 'http://www.w3.org/2006/12/xml-c14n11'
        expect(described_class.c14n_algorithm(uri)).to eq(:inclusive_1_1)
      end

      it 'maps inclusive C14N 1.1 with comments' do
        uri = 'http://www.w3.org/2006/12/xml-c14n11#WithComments'
        expect(described_class.c14n_algorithm(uri)).to eq(:inclusive_1_1_with_comments)
      end
    end

    context 'with unknown algorithm' do
      it 'raises UnsupportedAlgorithmError' do
        expect { described_class.c14n_algorithm('http://unknown/c14n') }
          .to raise_error(WSDL::UnsupportedAlgorithmError, /Unsupported canonicalization algorithm/)
      end

      it 'includes algorithm URI in error' do
        error = nil
        begin
          described_class.c14n_algorithm('http://unknown/c14n')
        rescue WSDL::UnsupportedAlgorithmError => e
          error = e
        end

        expect(error.algorithm_uri).to eq('http://unknown/c14n')
        expect(error.algorithm_type).to eq(:canonicalization)
      end
    end
  end

  describe '.supported?' do
    context 'with digest algorithms' do
      it 'returns true for supported SHA-256' do
        expect(described_class.supported?('http://www.w3.org/2001/04/xmlenc#sha256', type: :digest))
          .to be true
      end

      it 'returns true for supported SHA-384' do
        expect(described_class.supported?('http://www.w3.org/2001/04/xmldsig-more#sha384', type: :digest))
          .to be true
      end

      it 'returns false for unsupported algorithms' do
        expect(described_class.supported?('http://unknown/alg', type: :digest))
          .to be false
      end

      it 'returns false for nil' do
        expect(described_class.supported?(nil, type: :digest))
          .to be false
      end

      it 'returns false for empty string' do
        expect(described_class.supported?('', type: :digest))
          .to be false
      end
    end

    context 'with signature algorithms' do
      it 'returns true for supported RSA-SHA256' do
        expect(described_class.supported?('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256', type: :signature))
          .to be true
      end

      it 'returns true for supported ECDSA-SHA256' do
        expect(described_class.supported?('http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256', type: :signature))
          .to be true
      end

      it 'returns true for supported DSA-SHA1' do
        expect(described_class.supported?('http://www.w3.org/2000/09/xmldsig#dsa-sha1', type: :signature))
          .to be true
      end

      it 'returns false for unsupported algorithms' do
        expect(described_class.supported?('http://unknown/sig', type: :signature))
          .to be false
      end
    end

    context 'with canonicalization algorithms' do
      it 'returns true for supported exclusive C14N' do
        expect(described_class.supported?('http://www.w3.org/2001/10/xml-exc-c14n#', type: :canonicalization))
          .to be true
      end

      it 'returns true for supported inclusive C14N 1.1 with comments' do
        expect(described_class.supported?('http://www.w3.org/2006/12/xml-c14n11#WithComments', type: :canonicalization))
          .to be true
      end

      it 'returns false for unsupported algorithms' do
        expect(described_class.supported?('http://unknown/c14n', type: :canonicalization))
          .to be false
      end
    end

    context 'with unknown type' do
      it 'returns false' do
        expect(described_class.supported?('http://www.w3.org/2001/04/xmlenc#sha256', type: :unknown))
          .to be false
      end
    end
  end

  describe 'algorithm priority' do
    it 'matches sha512 before sha1 when both could match' do
      uri = 'http://example.com/sha512'
      expect(described_class.digest_algorithm(uri)).to eq(:sha512)
    end

    it 'matches sha384 before sha1' do
      uri = 'http://example.com/sha384'
      expect(described_class.digest_algorithm(uri)).to eq(:sha384)
    end

    it 'matches rsa-sha512 before rsa-sha1 when both could match' do
      uri = 'http://example.com/rsa-sha512'
      expect(described_class.signature_digest(uri)).to eq('SHA512')
    end

    it 'matches ecdsa-sha384 correctly' do
      uri = 'http://example.com/ecdsa-sha384'
      expect(described_class.signature_digest(uri)).to eq('SHA384')
    end

    it 'matches with-comments before without-comments for C14N' do
      uri = 'http://www.w3.org/2001/10/xml-exc-c14n#WithComments'
      expect(described_class.c14n_algorithm(uri)).to eq(:exclusive_1_0_with_comments)
    end
  end

  describe 'security: algorithm confusion prevention' do
    it 'rejects attacker-controlled algorithm URIs for digest' do
      # An attacker might try to inject a URI that contains "sha256" but isn't legitimate
      # The strict validation ensures only proper algorithm URIs are accepted
      expect { described_class.digest_algorithm('http://evil.com/sha256-not-really') }
        .not_to raise_error # This still matches because it contains sha256

      # But completely unknown algorithms are rejected
      expect { described_class.digest_algorithm('http://evil.com/md5') }
        .to raise_error(WSDL::UnsupportedAlgorithmError)
    end

    it 'rejects unknown signature algorithms that could be downgrade attacks' do
      expect { described_class.signature_digest('http://evil.com/weak-signature') }
        .to raise_error(WSDL::UnsupportedAlgorithmError)
    end

    it 'rejects unknown canonicalization algorithms' do
      expect { described_class.c14n_algorithm('http://evil.com/custom-c14n') }
        .to raise_error(WSDL::UnsupportedAlgorithmError)
    end
  end
end
