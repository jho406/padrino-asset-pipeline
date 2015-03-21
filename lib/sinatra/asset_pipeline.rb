require 'sprockets'
require 'sprockets-sass'
require 'sprockets-helpers'

module Sinatra
  module AssetPipeline
    class App < ::Sinatra::Base
    end

    module Helpers
      include Sprockets::Helpers

      def asset_path(source, options = {})
        uri = URI.parse(source)
        return source if uri.absolute?

        path = super

        prefix = settings.assets_path
          .sub(File.join(Padrino.root, 'public'), '')
          .sub(settings.path_prefix.to_s, '')

        if path.is_a?(Array)
          ([] << prefix << path).flatten
        else
          prefix + path
        end
      end

      def assets_environment
        settings.sprockets
      end

      def find_asset_path(uri, options = {})
        options = options.merge(prefix: settings.path_prefix)

        if settings.assets_manifest && options[:manifest] != false
          manifest_path = settings.assets_manifest.assets[uri.path]
          if manifest_path
            return Sprockets::Helpers::ManifestPath.new(uri, manifest_path, options)
          end
        end

        assets_environment.resolve(uri.path) do |path|
          return Sprockets::Helpers::AssetPath.new(uri, assets_environment[path], options)
        end

        return Sprockets::Helpers::FilePath.new(uri, options)
      end
    end

    def self.registered(app)
      app.set_default :sprockets, Sprockets::Environment.new
      app.set_default :assets_precompile, %w(app.js app.css *.png *.jpg *.svg *.eot *.ttf *.woff)
      app.set_default :assets_prefix, %w(assets vendor/assets)
      app.set_default :assets_path, -> { File.join(public_folder, "assets") }
      app.set_default :assets_protocol, :http
      app.set_default :assets_css_compressor, nil
      app.set_default :assets_js_compressor, nil
      app.set_default :assets_host, nil
      app.set_default :assets_digest, true
      app.set_default :assets_debug, false
      app.set_default :assets_manifest, nil
      app.set_default :path_prefix, nil
      app.set_default :url_prefix, 'assets'

      app.set :static, :true
      app.set :static_cache_control, [:public, :max_age => 60 * 60 * 24 * 365]

      app.configure do
        app.assets_prefix.each do |prefix|
          paths = Dir[File.join(app.root, prefix, '*')]
          paths.each { |path| app.sprockets.append_path path }
        end

        Sprockets::Helpers.configure do |config|
          config.environment = app.sprockets
          config.digest = app.assets_digest
          config.prefix = app.path_prefix unless app.path_prefix.nil?
          config.debug = app.assets_debug
        end
      end

      app.configure :staging, :production do
        manifest = Sprockets::Manifest.new(app.sprockets, app.assets_path)
        Sprockets::Helpers.configure do |config|
          config.manifest = manifest
          # config.prefix = app.path_prefix unless app.path_prefix.nil?
        end
        app.set :assets_manifest, manifest
      end

      app.configure :production do
        app.sprockets.css_compressor = app.assets_css_compressor unless app.assets_css_compressor.nil?
        app.sprockets.js_compressor = app.assets_js_compressor unless app.assets_js_compressor.nil?

        Sprockets::Helpers.configure do |config|
          config.protocol = app.assets_protocol
          config.asset_host = app.assets_host unless app.assets_host.nil?
          config.prefix = app.path_prefix unless app.path_prefix.nil?
        end
      end

      app.helpers Helpers

      app.configure :test, :development do
        puts app.url_prefix.to_s
        App.get "#{app.url_prefix.to_s}/:path" do |path|
          puts path
          env_sprockets = request.env.dup
          env_sprockets['PATH_INFO'] = path
          app.settings.sprockets.call env_sprockets
        end
      end
    end

    def set_default(key, default)
      self.set(key, default) unless self.respond_to? key
    end
  end
end
