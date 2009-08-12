require 'test/helper.rb'

class SubmitterTest < Test::Unit::TestCase
  context "with a new Submitter, a Notice that returns XML" do
    setup do
      @notice_xml = "XML"
      @notice = HoptoadNotifier::Notice.new
      @notice.stubs(:to_xml).returns(@notice_xml)

      @submitter = HoptoadNotifier::Submitter.new
    end

    should "POST the XML to the Hoptoad application when calling Submitter#submit" do
      http = stub(:read_timeout= => nil, :open_timeout= => nil, :use_ssl= => nil)

      proxy = stub(:new => http)
      Net::HTTP.stubs(:Proxy).returns(proxy)

      http.expects(:post).with(HoptoadNotifier.url.path, @notice_xml)

      @submitter.submit(@notice)
    end

    should "use the HTTP proxy configuration given" do
      HoptoadNotifier.proxy_host = "test.host"
      HoptoadNotifier.proxy_port = "1234"
      HoptoadNotifier.proxy_user = "username"
      HoptoadNotifier.proxy_pass = "password"

      http = stub(:read_timeout= => nil, :open_timeout= => nil, :use_ssl= => nil, :post => nil)
      proxy = stub(:new => http)

      Net::HTTP.expects(:Proxy).with(
        HoptoadNotifier.proxy_host,
        HoptoadNotifier.proxy_port,
        HoptoadNotifier.proxy_user,
        HoptoadNotifier.proxy_pass
      ).returns(proxy)

      @submitter.submit(@notice)
    end

    should "use the connection configuration given" do
      HoptoadNotifier.http_read_timeout = 10
      HoptoadNotifier.http_open_timeout = 5
      HoptoadNotifier.host = "test.host"
      HoptoadNotifier.port = 1234

      http = stub(:post => nil)

      http.expects(:read_timeout=).with(HoptoadNotifier.http_read_timeout)
      http.expects(:open_timeout=).with(HoptoadNotifier.http_open_timeout)
      http.expects(:use_ssl=).with(!!HoptoadNotifier.secure)

      proxy = stub
      proxy.expects(:new).with("test.host", 1234).returns(http)
      Net::HTTP.stubs(:Proxy).returns(proxy)

      @submitter.submit(@notice)
    end

    should "log an error when HTTP times out" do
      http = stub(:read_timeout= => nil, :open_timeout= => nil, :use_ssl= => nil)
      proxy = stub(:new => http)
      Net::HTTP.stubs(:Proxy).returns(proxy)
      http.stubs(:post).raises(TimeoutError)

      HoptoadNotifier.expects(:log).with(:error, anything)

      @submitter.submit(@notice)
    end

    should_eventually "log success when the HTTP POST results in success" do
    end

    should_eventually "log failure when the HTTP POST result is not success" do
    end
  end
end
