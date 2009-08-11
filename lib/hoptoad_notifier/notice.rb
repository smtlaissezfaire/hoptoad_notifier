module HoptoadNotifier
  class Notice

    def initialize
      @notice = {
        "api-key" => HoptoadNotifier.api_key,
        "notifier" => {
          "name" => HoptoadNotifier::NAME,
          "version" => HoptoadNotifier::VERSION,
          "url" => HoptoadNotifier::URL
        },
        "server-environment" => ENV.to_hash.merge(
          "project-root" => File.expand_path(RAILS_ROOT),
          "environment-name" => RAILS_ENV
        ),
        "error" => {
          "backtrace" => convert_backtrace(caller[1..-1])
        }
      }
    end

    def request=(request)
      @notice["request"] ||= {}
      @notice["request"].merge!(
        "controller" => request.controller,
        "action"     => request.action,
        "url"        => "#{request.protocol}#{request.host}#{request.request_uri}",
        "params"     => request.parameters.to_hash,
        "cgi-data"   => request.headers.to_hash
      )
    end

    def session=(session)
      session = session.respond_to?(:to_hash) ? session.to_hash : session.instance_variable_get("@data")
      @notice["request"] ||= {}
      @notice["request"]["session"] = session
    end

    def error=(error)
      @notice["error"] ||= {}
      @notice["error"].merge!(
        "class" => error.class.to_s,
        "message" => error.message,
        "backtrace" => convert_backtrace(error.backtrace)
      )
    end

    def valid?
    end

    def to_xml
      builder = Builder::XmlMarkup.new
      xml = builder.notice(:version => HoptoadNotifier::VERSION) do |notice| 
        notice.tag!("api-key", api_key)
        notice.notifier do |notifier|
          notifier.name(notifier_name)
          notifier.version(notifier_version)
          notifier.url(notifier_url)
        end
        notice.error do |error|
          error.class(error_class)
          error.message(error_message)
          error.backtrace do |backtrace|
            error_backtrace.each do |line|
              backtrace.line(:number => line["number"],
                             :file   => line["file"],
                             :method => line["method"])
            end
          end
        end
        notice.request do |request|
          request.url(request_url)
          request.controller(request_controller)
          request.action(request_action)
          unless request_parameters.blank?
            request.params do |params|
              xml_vars_for(params, request_parameters)
            end
          end
          unless request_session.blank?
            request.session do |session|
              xml_vars_for(session, request_session)
            end
          end
          unless request_headers.blank?
            request.tag!("cgi-data") do |headers|
              xml_vars_for(headers, request_headers)
            end
          end
        end
        notice.tag!("server-environment") do |env|
          env.tag!("project-root", project_root)
          env.tag!("environment-name", environment_name)
          dup_env = server_environment.dup
          dup_env.delete("project-root")
          dup_env.delete("environment-name")
          xml_vars_for(env, dup_env)
        end
      end
      xml.to_s
    end

    def xml_vars_for(builder, hash)
      hash.each do |key, value|
        if value.is_a?(Hash)
          builder.var(:key => key){|b| xml_vars_for(b, value) }
        else
          builder.var(value.to_s, :key => key)
        end
      end
    end

    def api_key;            field('api-key');                                end
    def server_environment; field('server-environment');                     end
    def project_root;       field('server-environment')['project-root'];     end
    def environment_name;   field('server-environment')['environment-name']; end
    def notifier_name;      field('notifier')['name'];                       end
    def notifier_version;   field('notifier')['version'];                    end
    def notifier_url;       field('notifier')['url'];                        end
    def request_controller; field('request')['controller'];                  end
    def request_action;     field('request')['action'];                      end
    def request_url;        field('request')['url'];                         end
    def request_parameters; field('request')['params'];                      end
    def request_headers;    field('request')['cgi-data'];                    end
    def request_session;    field('request')['session'];                     end
    def error_class;        field('error')['class'];                         end
    def error_message;      field('error')['message'];                       end
    def error_backtrace;    field('error')['backtrace'];                     end

    def error_class=(classname)
      @notice['error'] ||= {}
      @notice['error']['class'] = classname
    end

    def error_message=(message)
      @notice['error'] ||= {}
      @notice['error']['message'] = message
    end

    protected

    def field(key)
      @notice[key]
    end

    BACKTRACE_LINE = %r{^([^:]+):(\d+)(?::in `([^']+)')?$}.freeze
    def convert_backtrace(backtrace)
      backtrace.map do |line|
        _, file, number, methodname = line.match(BACKTRACE_LINE).to_a
        {"file" => file, "number" => number, "method" => methodname }
      end
    end
  end
end
