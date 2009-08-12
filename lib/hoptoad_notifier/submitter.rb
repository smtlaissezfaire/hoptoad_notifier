module HoptoadNotifier
  class Submitter
    def submit(notice)
      url = HoptoadNotifier.url
      http = Net::HTTP::Proxy(HoptoadNotifier.proxy_host,
                              HoptoadNotifier.proxy_port,
                              HoptoadNotifier.proxy_user,
                              HoptoadNotifier.proxy_pass).new(url.host, url.port)

      http.read_timeout = HoptoadNotifier.http_read_timeout
      http.open_timeout = HoptoadNotifier.http_open_timeout
      http.use_ssl = !!HoptoadNotifier.secure

      response = begin
                   http.post(url.path, notice.to_xml)
                 rescue TimeoutError => e
                   HoptoadNotifier.log :error, "Timeout while contacting the Hoptoad server."
                   return nil
                 end

      case response
      when Net::HTTPSuccess then
        HoptoadNotifier.log :info, "Success: #{response.class}", response
      else
        HoptoadNotifier.log :error, "Failure: #{response.class}", response
      end
    end
  end
end
