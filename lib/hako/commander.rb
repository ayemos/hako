require 'yaml'
require 'hako/env_expander'
require 'hako/error'
require 'hako/schedulers'

module Hako
  class Commander
    PROVIDERS_KEY = '$providers'

    def initialize(yaml_path)
      @app_id = Pathname.new(yaml_path).basename.sub_ext('').to_s
      @yaml = YAML.load_file(yaml_path)
    end

    def apply
      env = @yaml['env'].dup
      providers = load_providers(env.delete(PROVIDERS_KEY) || [])
      env = EnvExpander.new(providers).expand(env)

      scheduler = load_scheduler(@yaml['scheduler'])
      port_mappings = @yaml['port_mappings'] || []
      image_tag = @yaml['image']  # TODO: Append revision
      scheduler.deploy(image_tag, env, port_mappings)
    end

    private

    def load_providers(provider_configs)
      provider_configs.map do |config|
        type = config['type']
        unless type
          raise Error.new("type must be set in each #{PROVIDERS_KEY} element")
        end
        require "hako/env_providers/#{type}"
        Hako::EnvProviders.const_get(camelize(type)).new(config)
      end
    end

    def load_scheduler(scheduler_config)
      type = scheduler_config['type']
      unless type
        raise Error.new('type must be set in scheduler')
      end
      require "hako/schedulers/#{type}"
      Hako::Schedulers.const_get(camelize(type)).new(@app_id, scheduler_config)
    end

    def camelize(name)
      name.split('_').map(&:capitalize).join('')
    end
  end
end
