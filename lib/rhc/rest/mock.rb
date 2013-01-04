require "rhc/rest"

module RHC::Rest::Mock

  def self.start
    RHC::Helpers.warn "Running in mock mode"
    MockRestClient.new.tap do |c|
      d = c.add_domain("test1")
      app = d.add_application('app1', 'carttype1')
      app.cartridges[0].display_name = "A display name"
      app.add_cartridge('mockcart2')
      app2 = d.add_application('app2', 'carttype2', true)
    end
  end

  module Helpers

    def mock_user
      "test_user"
    end

    def stub_api_request(method, uri, with_auth=true)
      stub_request(method, mock_href(uri, with_auth)).
        with(&user_agent_header)
    end

    def mock_pass
      "test pass"
    end

    def mock_uri
      "test.domain.com"
    end

    # Creates consistent hrefs for testing
    def mock_href(relative="", with_auth=false)
      uri_string =
        if with_auth == true
          "#{mock_user}:#{mock_pass}@#{mock_uri}"
        elsif with_auth
          "#{with_auth[:user]}:#{with_auth[:password]}@#{mock_uri}"
        else
          mock_uri
        end
      "https://#{uri_string}/#{relative}"
    end

    # This formats link lists for JSONification
    def mock_response_links(links)
      link_set = {}
      links.each do |link|
        operation = link[0]
        href      = link[1]
        method    = link[2]
        # Note that the 'relative' key/value pair below is a convenience for testing;
        # this is not used by the API classes.
        link_set[operation] = { 'href' => mock_href(href), 'method' => method, 'relative' => href }
      end
      return link_set
    end

    def mock_app_links(domain_id='test_domain',app_id='test_app')
      [['ADD_CARTRIDGE',   "domains/#{domain_id}/apps/#{app_id}/carts/add", 'post'],
       ['LIST_CARTRIDGES', "domains/#{domain_id}/apps/#{app_id}/carts/",    'get' ],
       ['GET_GEAR_GROUPS', "domains/#{domain_id}/apps/#{app_id}/gear_groups", 'get' ],
       ['START',           "domains/#{domain_id}/apps/#{app_id}/start",     'post'],
       ['STOP',            "domains/#{domain_id}/apps/#{app_id}/stop",      'post'],
       ['RESTART',         "domains/#{domain_id}/apps/#{app_id}/restart",   'post'],
       ['THREAD_DUMP',     "domains/#{domain_id}/apps/#{app_id}/event",     'post'],
       ['ADD_ALIAS',       "domains/#{domain_id}/apps/#{app_id}/event",     'post'],
       ['REMOVE_ALIAS',    "domains/#{domain_id}/apps/#{app_id}/event",     'post'],
       ['DELETE',          "domains/#{domain_id}/apps/#{app_id}/delete",    'post']]
    end

    def mock_cart_links(domain_id='test_domain',app_id='test_app',cart_id='test_cart')
      [['START',   "domains/#{domain_id}/apps/#{app_id}/carts/#{cart_id}/start",   'post'],
       ['STOP',    "domains/#{domain_id}/apps/#{app_id}/carts/#{cart_id}/stop",    'post'],
       ['RESTART', "domains/#{domain_id}/apps/#{app_id}/carts/#{cart_id}/restart", 'post'],
       ['DELETE',  "domains/#{domain_id}/apps/#{app_id}/carts/#{cart_id}/delete",  'post']]
    end

    def mock_client_links
      [['GET_USER',        'user/',       'get' ],
       ['ADD_DOMAIN',      'domains/add', 'post'],
       ['LIST_DOMAINS',    'domains/',    'get' ],
       ['LIST_CARTRIDGES', 'cartridges/', 'get' ]]
    end
    def mock_real_client_links
      [['GET_USER',        "broker/rest/user",       'GET'],
       ['LIST_DOMAINS',    "broker/rest/domains",    'GET'],
       ['ADD_DOMAIN',      "broker/rest/domains",    'POST'],
       ['LIST_CARTRIDGES', "broker/rest/cartridges", 'GET'],
      ]
    end

    def mock_domain_links(domain_id='test_domain')
      [['ADD_APPLICATION',   "domains/#{domain_id}/apps/add", 'post'],
       ['LIST_APPLICATIONS', "domains/#{domain_id}/apps/",    'get' ],
       ['UPDATE',            "domains/#{domain_id}/update",   'post'],
       ['DELETE',            "domains/#{domain_id}/delete",   'post']]
    end

    def mock_key_links(key_id='test_key')
      [['UPDATE', "user/keys/#{key_id}/update", 'post'],
       ['DELETE', "user/keys/#{key_id}/delete", 'post']]
    end

    def mock_user_links
      [['ADD_KEY',   'user/keys/add', 'post'],
       ['LIST_KEYS', 'user/keys/',    'get' ]]
    end

    def mock_cartridge_response(cart_count=1)
      carts = []
      while carts.length < cart_count
        carts << {
          :name  => "mock_cart_#{carts.length}",
          :type  => "mock_cart_#{carts.length}_type",
          :links => mock_response_links(mock_cart_links('mock_domain','mock_app',"mock_cart_#{carts.length}"))
        }
      end

      carts = carts[0] if cart_count == 1
      type  = cart_count == 1 ? 'cartridge' : 'cartridges'

      return {
        :body   => {
          :type => type,
          :data => carts
        }.to_json,
        :status => 200
      }
    end

    def mock_gear_groups_response()
      groups = [{}]
      type  = 'gear_groups'

      return {
        :body   => {
          :type => type,
          :data => groups
        }.to_json,
        :status => 200
      }
    end
  end

  class MockRestClient < RHC::Rest::Client
    include Helpers

    def initialize(config=RHC::Config)
      obj = self
      if RHC::Rest::Client.respond_to?(:stub)
        RHC::Rest::Client.stub(:new) { obj }
      else
        RHC::Rest::Client.instance_eval do
          @obj = obj
          def new(*args)
            @obj
          end
        end
      end
      @domains = []
      @user = MockRestUser.new(client, config.username)
      @api = MockRestApi.new(client, config)
    end

    def api
      @api
    end

    def user
      @user
    end

    def domains
      @domains
    end

    def cartridges
      [MockRestCartridge.new(self, "mock_cart-1", "embedded"), # code should sort this to be after standalone
       MockRestCartridge.new(self, "mock_standalone_cart-1", "standalone"),
       MockRestCartridge.new(self, "mock_standalone_cart-2", "standalone"),
       MockRestCartridge.new(self, "mock_unique_standalone_cart-1", "standalone"),
       MockRestCartridge.new(self, "jenkins-1.4", "standalone"),
       MockRestCartridge.new(self, "mock_cart-2", "embedded"),
       MockRestCartridge.new(self, "unique_mock_cart-1", "embedded"),
       MockRestCartridge.new(self, "jenkins-client-1.4", "embedded")]
    end

    def add_domain(id)
      d = MockRestDomain.new(self, id)
      @domains << d
      d
    end

    def sshkeys
      @user.keys
    end

    def add_key(name, type, content)
      @user.add_key(name, type, content)
    end

    def delete_key(name)
      @user.keys.delete_if { |key| key.name == name }
    end
  end

  class MockRestApi < RHC::Rest::Api
    include Helpers

    def initialize(client, config)
      @client = client
      @client_api_versions = RHC::Rest::Client::CLIENT_API_VERSIONS
      @server_api_versions = @client_api_versions
      self.attributes = {:links => mock_response_links(mock_client_links)}
    end
  end

  class MockRestUser < RHC::Rest::User
    include Helpers
    def initialize(client, login)
      super({}, client)
      @login = login
      @keys = [
        MockRestKey.new(client, 'mockkey1', 'ssh-rsa', 'AAAAB3NzaC1yc2EAAAADAQABAAABAQDNK8xT3O+kSltmCMsSqBfAgheB3YFJ9Y0ESJnFjFASVxH70AcCQAgdQSD/r31+atYShJdP7f0AMWiQUTw2tK434XSylnZWEyIR0V+j+cyOPdVQlns6D5gPOnOtweFF0o18YulwCOK8Q1H28GK8qyWhLe0FcMmxtKbbQgaVRvQdXZz4ThzutCJOyJm9xVb93+fatvwZW76oLLvfFJcJSOK2sgW7tJM2A83bm4mwixFDF7wO/+C9WA+PgPKJUIjvy1gZjBhRB+3b58vLOnYhPOgMNruJwzB+wJ3pg8tLJEjxSbHyyoi6OqMBs4BVV7LdzvwTDxEjcgtHVvaVNXgO5iRX'),
        MockRestKey.new(client, 'mockkey2', 'ssh-dsa', 'AAAAB3NzaC1kc3MAAACBAPaaFj6Xjrjd8Dc4AAkJe0HigqaXMxj/87xHoV+nPgerHIceJWhPUWdW40lSASrgpAV9Eq4zzD+L19kgYdbMw0vSX5Cj3XtNOsow9MmMxFsYjTxCv4eSs/rLdGPaYZ5GVRPDu8tN42Bm8lj5o+ky3HzwW+mkQMZwcADQIgqtn6QhAAAAFQCirDfIMf/JoMOFf8CTnsTKWw/0zwAAAIAIQp6t2sLIp1d2TBfd/qLjOJA10rPADcnhBzWB/cd/oFJ8a/2nmxeSPR5Ov18T6itWqbKwvZw2UC0MrXoYbgcfVNP/ym1bCd9rB5hu1sg8WO4JIxA/47PZooT6PwTKVxHuENEzQyJL2o6ZJq+wuV0taLvm6IaM5TAZuEJ2p4TC/gAAAIBpLcVXZREa7XLY55nyidt/+UC+PxpjhPHOHbzL1OvWEaumN4wcJk/JZPppgXX9+WDkTm1SD891U0cXnGMTP0OZOHkOUHF2ZcfUe7p9kX4WjHs0OccoxV0Lny6MC4DjalJyaaEbijJHSUX3QlLcBOlPHJWpEpvWQ9P8AN4PokiGzA==')
      ]
    end

    def keys
      @keys
    end

    def add_key(name, type, content)
      @keys << MockRestKey.new(client, name, type, content)
    end
  end

  class MockRestDomain < RHC::Rest::Domain
    include Helpers
    def initialize(client, id)
      super({}, client)
      @id = id
      @applications = []
      self.attributes = {:links => mock_response_links(mock_domain_links('mock_domain_0'))}
    end

    def update(id)
      @id = id
      self
    end

    def destroy
      raise RHC::Rest::ClientErrorException.new("Applications must be empty.") unless @applications.empty?
      client.domains.delete_if { |d| d.id == @id }

      @applications = nil
    end

    def add_application(name, type=nil, scale=nil, gear_profile='default')
      if type.is_a?(Hash)
        scale = type[:scale]
        gear_profile = type[:gear_profile]
        type = type[:cartridge]
      end
      a = MockRestApplication.new(client, name, type, self, scale, gear_profile)
      builder = @applications.find{ |app| app.cartridges.map(&:name).any?{ |s| s =~ /^jenkins-[\d\.]+$/ } }
      a.building_app = builder.name if builder
      @applications << a
      a.add_message("Success")
      a
    end

    def applications(*args)
      @applications
    end
  end

  class MockRestGearGroup < RHC::Rest::GearGroup
    include Helpers
    def initialize(client=nil)
      super({}, client)
      @cartridges = [{'name' => 'fake_geargroup_cart-0.1'}]
      @gears = [{'state' => 'started', 'id' => 'fakegearid'}]
    end
  end

  class MockRestApplication < RHC::Rest::Application
    include Helpers
    def fakeuuid
      "fakeuuidfortests#{@name}"
    end

    def initialize(client, name, type, domain, scale=nil, gear_profile='default')
      super({}, client)
      @name = name
      @domain = domain
      @cartridges = []
      @creation_time = Date.new(2000, 1, 1).strftime('%Y-%m-%dT%H:%M:%S%z')
      @uuid = fakeuuid
      @git_url = "git:fake.foo/git/#{@name}.git"
      @app_url = "https://#{@name}-#{@domain.id}.fake.foo/"
      @ssh_url = "ssh://#{@uuid}@127.0.0.1"
      @embedded = {}
      @aliases = []
      @gear_profile = gear_profile
      if scale
        @scalable = true
        @embedded = {"haproxy-1.4" => {:info => ""}}
      end
      self.attributes = {:links => mock_response_links(mock_app_links('mock_domain_0', 'mock_app_0')), :messages => []}
      cart = add_cartridge(type, false) if type
      if scale
        cart.supported_scales_to = (cart.scales_to = -1)
        cart.supported_scales_from = (cart.scales_from = 2)
        cart.current_scale = 2
        cart.scales_with = "haproxy-1.4"
      end
      @framework = type
    end

    def destroy
      @domain.applications.delete self
    end

    def add_cartridge(name, embedded=true)
      type = embedded ? "embedded" : "standalone"
      c = MockRestCartridge.new(client, name, type, self)
      c.properties << {'name' => 'prop1', 'value' => 'value1', 'description' => 'description1' }
      @cartridges << c
      c.messages << "Cartridge added with properties"
      c
    end

    def gear_groups
      # we don't have heavy interaction with gear groups yet so keep this simple
      @gear_groups ||= [MockRestGearGroup.new(client)]
    end

    def cartridges
      @cartridges
    end

    def start
      @app
    end

    def stop(*args)
      @app
    end

    def restart
      @app
    end

    def reload
      @app
    end

    def tidy
      @app
    end
  end

  class MockRestCartridge < RHC::Rest::Cartridge
    include Helpers
    def initialize(client, name, type, app=nil, properties=[{'type' => 'cart_data', 'name' => 'connection_url', 'value' => "http://fake.url" }])
      super({}, client)
      @name = name
      @type = type
      @app = app
      @properties = properties.each(&:stringify_keys!)
      @status_messages = [{"message" => "started", "gear_id" => "123"}]
      @scales_from = 1
      @scales_to = 1
      @current_scale = 1
      @gear_profile = 'small'
    end

    def destroy
      @app.cartridges.delete self
    end

    def status
      @status_messages
    end

    def start
      @status_messages = [{"message" => "started", "gear_id" => "123"}]
      @app
    end

    def stop
      @status_messages = [{"message" => "stopped", "gear_id" => "123"}]
      @app
    end

    def restart
      @status_messages = [{"message" => "started", "gear_id" => "123"}]
      @app
    end

    def reload
      @app
    end

    def set_scales(values)
      values.delete_if{|k,v| v.nil? }
      @scales_from = values[:scales_from] if values[:scales_from]
      @scales_to = values[:scales_to] if values[:scales_to]
      self
    end
  end

  class MockRestKey < RHC::Rest::Key
    include Helpers
    def initialize(client, name, type, content)
      super({}, client)
      @name    = name
      @type    = type
      @content = content
    end
  end
end

