require 'test/helper'

class NoticeTest < Test::Unit::TestCase
  SCHEMA_PATH = File.join(File.dirname(__FILE__), "hoptoad_2_0.xsd")

  def get_exception(message)
    begin; raise message; rescue Exception => caught; caught; end
  end

  context "on initialize" do
    setup do
      HoptoadNotifier.api_key = "1234567890"
      @notice = HoptoadNotifier::Notice.new
    end

    should "set the api key" do
      assert_equal "1234567890", @notice.api_key
    end

    should "set the notifier url" do
      assert_equal "http://hoptoadapp.com", @notice.notifier.url
    end

    should "set the notifier version" do
      assert_equal "2.0.0", @notice.notifier.version
    end

    should "set the notifier name" do
      assert_equal "Hoptoad Notifier", @notice.notifier.name
    end
  end

  context "setting the error with an exception" do
    setup do
      @notice = HoptoadNotifier::Notice.new
      @exception = get_exception("OMG")
      @notice.error = @exception
    end

    should "set the error backtrace" do
      assert_equal HoptoadNotifier::Notice::Line.new(__FILE__, "7", "get_exception"),
                   @notice.error.backtrace.first
    end

    should "set the error message" do
      assert_equal "OMG", @notice.error.message
    end

    should "set the error class" do
      assert_equal "RuntimeError", @notice.error.class
    end
  end

  should "be able to set the error backtrace by hand" do
    @notice = HoptoadNotifier::Notice.new
    @notice.error.backtrace = get_exception("OMG").backtrace
    assert_equal HoptoadNotifier::Notice::Line.new(__FILE__, "7", "get_exception"),
                 @notice.error.backtrace.first
  end

  should "default the vars to an empty hash when creating a ServerEnvironment" do
    @env = HoptoadNotifier::Notice::ServerEnvironment.new(nil, nil, nil)
    assert_equal({}, @env.vars)
  end

  should "default the params, session, and cgi_data to empty hashes when creating a Request" do
    @request = HoptoadNotifier::Notice::Request.new(nil, nil, nil, nil, nil, nil)
    assert_equal({}, @request.params)
    assert_equal({}, @request.session)
    assert_equal({}, @request.cgi_data)
  end

  def assert_valid_node(document, xpath, content)
    nodes = document.xpath(xpath)
    assert nodes.any?{|node| node.content == content },
           "Expected xpath #{xpath} to have content #{content}, " +
           "but found #{nodes.map { |n| n.content }} in #{nodes.size} matching nodes."
  end

  context "a Notice turned into XML" do
    setup do
      HoptoadNotifier.api_key = "1234567890"
      @notice = HoptoadNotifier::Notice.new
      @notice.error = get_exception("OMG")

      @notice.request.controller = "controller"
      @notice.request.action     = "action"
      @notice.request.url        = "http://url.com"
      @notice.request.params     = { "paramskey"     => "paramsvalue",
                                     "nestparentkey" => { "nestkey" => "nestvalue" } }
      @notice.request.session    = { "sessionkey"    => "sessionvalue" }
      @notice.request.cgi_data   = { "cgikey"        => "cgivalue" }

      @notice.server_environment.project_root     = "RAILS_ROOT"
      @notice.server_environment.environment_name = "RAILS_ENV"
      @notice.server_environment.vars             = { "varkey" => "varvalue" }

      @xml = @notice.to_xml

      @document = Nokogiri::XML::Document.parse(@xml)
    end

    should "validate against the XML schema" do
      xsd_path = File.join(File.dirname(__FILE__), "hoptoad_2_0.xsd")
      schema = Nokogiri::XML::Schema.new(IO.read(xsd_path))
      errors = schema.validate(@document)
      assert errors.empty?, errors.collect{|e| e.message }.join
    end

    should "serialize a Notice to XML when sent #to_xml" do
      assert_valid_node(@document, "//api-key", "1234567890")

      assert_valid_node(@document, "//notifier/name", "Hoptoad Notifier")
      assert_valid_node(@document, "//notifier/version", "2.0.0")
      assert_valid_node(@document, "//notifier/url", "http://hoptoadapp.com")

      assert_valid_node(@document, "//error/class", "RuntimeError")
      assert_valid_node(@document, "//error/message", "OMG")
      assert_valid_node(@document, "//error/backtrace/line/@number", "7")
      assert_valid_node(@document, "//error/backtrace/line/@file", __FILE__)
      assert_valid_node(@document, "//error/backtrace/line/@method", "get_exception")

      assert_valid_node(@document, "//request/url"                , "http://url.com")
      assert_valid_node(@document, "//request/controller"         , "controller")
      assert_valid_node(@document, "//request/action"             , "action")
      assert_valid_node(@document, "//request/params/var/@key"     , "paramskey")
      assert_valid_node(@document, "//request/params/var"         , "paramsvalue")
      assert_valid_node(@document, "//request/params/var/@key"     , "nestparentkey")
      assert_valid_node(@document, "//request/params/var/var/@key" , "nestkey")
      assert_valid_node(@document, "//request/params/var/var"     , "nestvalue")
      assert_valid_node(@document, "//request/session/var/@key"    , "sessionkey")
      assert_valid_node(@document, "//request/session/var"        , "sessionvalue")
      assert_valid_node(@document, "//request/cgi-data/var/@key"   , "cgikey")
      assert_valid_node(@document, "//request/cgi-data/var"       , "cgivalue")

      assert_valid_node(@document, "//server-environment/project-root", "RAILS_ROOT")
      assert_valid_node(@document, "//server-environment/environment-name", "RAILS_ENV")
      assert_valid_node(@document, "//server-environment/var/@key"     , "varkey")
      assert_valid_node(@document, "//server-environment/var"         , "varvalue")
    end
  end

  should "clean up params" do
    # set a param that will be cleaned
    # assert that it is not present
  end

  should "clean up environment" do
    # set an environment var that will be cleaned
    # assert that it is not present
  end

  should "filter the backtrace" do
    # set a backtrace with a line that will be cleaned
    # assert that it is not present
  end
end
