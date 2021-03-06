module Restforce
  class Client
    # Public: Creates a new client instance
    #
    # options - A hash of options to be passed in (default: {}).
    #           :username       - The String username to use (required for password authentication).
    #           :password       - The String password to use (required for password authentication).
    #           :security_token - The String security token to use 
    #                             (required for password authentication).
    #
    #           :oauth_token    - The String oauth access token to authenticate api
    #                             calls (required unless password
    #                             authentication is used).
    #           :refresh_token  - The String refresh token to obtain fresh
    #                             oauth access tokens (required if oauth
    #                             authentication is used).
    #           :instance_url   - The String base url for all api requests
    #                             (required if oauth authentication is used).
    #
    #           :client_id      - The oauth client id to use. Needed for both
    #                             password and oauth authentication
    #           :client_secret  - The oauth client secret to use.
    #
    #           :host           - The String hostname to use during
    #                             authentication requests (default: 'login.salesforce.com').
    #
    #           :api_version    - The String REST api version to use (default: '24.0')
    #
    # Examples
    #
    #   # Initialize a new client using password authentication:
    #   Restforce::Client.new :username => 'user',
    #     :password => 'pass',
    #     :security_token => 'security token',
    #     :client_id => 'client id',
    #     :client_secret => 'client secret'
    #   # => #<Restforce::Client:0x007f934aa2dc28 @options={ ... }>
    #
    #   # Initialize a new client using oauth authentication:
    #   Restforce::Client.new :oauth_token => 'access token',
    #     :refresh_token => 'refresh token',
    #     :instance_url => 'https://na1.salesforce.com',
    #     :client_id => 'client id',
    #     :client_secret => 'client secret'
    #   # => #<Restforce::Client:0x007f934aaaa0e8 @options={ ... }>
    #
    #   # Initialize a new client with using any authentication middleware:
    #   Restforce::Client.new :oauth_token => 'access token',
    #     :instance_url => 'https://na1.salesforce.com'
    #   # => #<Restforce::Client:0x007f934aab9980 @options={ ... }>
    def initialize(options = {})
      raise 'Please specify a hash of options' unless options.is_a?(Hash)
      @options = {}.tap do |options|
        [:username, :password, :security_token, :client_id, :client_secret, :host,
         :api_version, :oauth_token, :refresh_token, :instance_url].each do |option|
          options[option] = Restforce.configuration.send option
        end
      end
      @options.merge!(options)
    end

    # Public: Get the global describe for all sobjects.
    #
    # Returns the Hash representation of the describe call.
    def describe_sobjects
      response = api_get 'sobjects'
      response.body['sobjects']
    end

    # Public: Get the names of all sobjects on the org.
    #
    # Examples
    #
    #   # get the names of all sobjects on the org
    #   client.list_sobjects
    #   # => ['Account', 'Lead', ... ]
    #
    # Returns an Array of String names for each SObject.
    def list_sobjects
      describe_sobjects.collect { |sobject| sobject['name'] }
    end
    
    # Public: Returns a detailed describe result for the specified sobject
    #
    # sobject - Stringish name of the sobject (default: nil).
    #
    # Examples
    #
    #   # get the describe for the Account object
    #   client.describe('Account')
    #   # => { ... }
    #
    # Returns the Hash representation of the describe call.
    def describe(sobject)
      response = api_get "sobject/#{sobject.to_s}/describe"
      response.body
    end

    # Public: Get the current organization's Id.
    #
    # Examples
    #
    #   client.org_id
    #   # => '00Dx0000000BV7z'
    #
    # Returns the String organization Id
    def org_id
      query('select id from Organization').first['Id']
    end
    
    # Public: Executs a SOQL query and returns the result.
    #
    # Examples
    #
    #   # Find the names of all Accounts
    #   client.query('select Name from Account').map(&:Name)
    #   # => ['Foo Bar Inc.', 'Whizbang Corp']
    #
    # Returns a Restforce::Collection if Restforce.configuration.mashify is true.
    # Returns an Array of Hash for each record in the result if Restforce.configuration.mashify is false.
    def query(query)
      response = api_get 'query', q: query
      mashify? ? response.body : response.body['records']
    end
    
    # Public: Perform a SOSL search
    #
    # Examples
    #
    #   # Find all occurrences of 'bar'
    #   client.search('FIND {bar}')
    #   # => #<Restforce::Collection >
    #
    #   # Find accounts match the term 'genepoint' and return the Name field
    #   client.search('FIND {genepoint} RETURNING Account (Name)').map(&:Name)
    #   # => ['GenePoint']
    #
    # Returns a Restforce::Collection if Restforce.configuration.mashify is true.
    # Returns an Array of Hash for each record in the result if Restforce.configuration.mashify is false.
    def search(term)
      response = api_get 'search', q: term
      response.body
    end
    
    # Public: Insert a new record.
    #
    # Examples
    #
    #   # Add a new account
    #   client.create('Account', Name: 'Foobar Inc.')
    #   # => '0016000000MRatd'
    #
    # Returns the String Id of the newly created sobject.
    def create(sobject, attrs)
      response = api_post "sobjects/#{sobject}", attrs
      response.body['id']
    end

    # Public: Update a record.
    #
    # Examples
    #
    #   # Update the Account with Id '0016000000MRatd'
    #   client.update('Account', Id: '0016000000MRatd', Name: 'Whizbang Corp')
    #
    # Returns true if the sobject was successfully updated, false otherwise.
    def update(sobject, attrs)
      update!(sobject, attrs)
    rescue Faraday::Error::ResourceNotFound
      false
    end

    # See .update
    #
    # Returns true if the sobject was successfully updated, raises an error
    # otherwise.
    def update!(sobject, attrs)
      id = attrs.has_key?(:Id) ? attrs.delete(:Id) : attrs.delete('Id')
      api_patch "sobjects/#{sobject}/#{id}", attrs
      true
    end

    # Public: Delete a record.
    #
    # Examples
    #
    #   # Delete the Account with Id '0016000000MRatd'
    #   client.delete('Account', '0016000000MRatd')
    #
    # Returns true if the sobject was successfully deleted, false otherwise.
    def destroy(sobject, id)
      destroy!(sobject, id)
    rescue Faraday::Error::ResourceNotFound
      false
    end

    # See .destroy
    #
    # Returns true of the sobject was successfully deleted, raises an error
    # otherwise.
    def destroy!(sobject, id)
      api_delete "sobjects/#{sobject}/#{id}"
      true
    end

    # Public: Helper methods for performing arbitrary actions against the API using
    # various HTTP verbs.
    #
    # Examples
    #
    #   # Perform a get request
    #   client.get '/services/data/v24.0/sobjects'
    #   client.api_get 'sobjects'
    #
    #   # Perform a post request
    #   client.post '/services/data/v24.0/sobjects/Account', { ... }
    #   client.api_post 'sobjects/Account', { ... }
    #
    #   # Perform a put request
    #   client.put '/services/data/v24.0/sobjects/Account/001D000000INjVe', { ... }
    #   client.api_put 'sobjects/Account/001D000000INjVe', { ... }
    #
    #   # Perform a delete request
    #   client.delete '/services/data/v24.0/sobjects/Account/001D000000INjVe'
    #   client.api_delete 'sobjects/Account/001D000000INjVe'
    #
    # Returns the Faraday::Response.
    [:get, :post, :put, :delete, :patch].each do |method|
      define_method method do |*args|
        begin
          connection.send(method, *args)
        rescue Restforce::InstanceURLError
          connection.url_prefix = @options[:instance_url]
          connection.send(method, *args)
        end
      end

      define_method :"api_#{method}" do |*args|
        args[0] = api_path(args[0])
        send(method, *args)
      end
    end

  private

    # Internal: Returns a path to an api endpoint
    #
    # Examples
    #
    #   api_path('sobjects')
    #   # => '/services/data/v24.0/sobjects'
    def api_path(path)
      "/services/data/v#{@options[:api_version]}/#{path}"
    end

    # Internal: Internal faraday connection where all requests go through
    def connection
      @connection ||= Faraday.new do |builder|
        builder.use Restforce::Middleware::Mashify, self, @options
        builder.use Restforce::Middleware::Multipart
        builder.request :json
        builder.use authentication_middleware, self, @options if authentication_middleware
        builder.use Restforce::Middleware::Authorization, self, @options
        builder.use Restforce::Middleware::InstanceURL, self, @options
        builder.use Restforce::Middleware::RaiseError
        builder.response :logger, Restforce.configuration.logger if Restforce.log?
        builder.response :json
        builder.adapter Faraday.default_adapter
      end
      @connection
    end

    # Internal: Determines what middleware will be used based on the options provided
    def authentication_middleware
      if username_password?
        Restforce::Middleware::Authentication::Password
      elsif oauth_refresh?
        Restforce::Middleware::Authentication::OAuth
      end
    end

    # Internal: Returns true if username/password (autonomous) flow should be used for
    # authentication.
    def username_password?
      @options[:username] &&
        @options[:password] &&
        @options[:security_token] &&
        @options[:client_id] &&
        @options[:client_secret]
    end

    # Internal: Returns true if oauth token refresh flow should be used for
    # authentication.
    def oauth_refresh?
      @options[:oauth_token] &&
        @options[:refresh_token] &&
        @options[:client_id] &&
        @options[:client_secret]
    end

    # Internal: Returns true if the middlware stack includes the
    # Restforce::Middleware::Mashify middleware.
    def mashify?
      connection.builder.handlers.find { |handler| handler == Restforce::Middleware::Mashify }
    end
  end
end
