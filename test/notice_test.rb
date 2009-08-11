require 'test/helper'

class NoticeTest < Test::Unit::TestCase
  SCHEMA_PATH = File.join(File.dirname(__FILE__), "hoptoad_2_0.xsd")

  def make_new_notice
    # This method exists to make testing the method name in a backtrace possible.
    HoptoadNotifier::Notice.new
  end

  def fake_request
    request = OpenStruct.new(
      :controller => "users",
      :action => "create",
      :protocol => "https://",
      :host => "test.host",
      :request_uri => "/users/?something=awesome",
      :parameters => {:one => 2, :three => 4, :five => {:six => 7, :eight => 9}},
      :headers => {"Content-type" => "text/plain"}
    )
    request.parameters.stubs(:to_hash).returns(request.parameters)
    request.headers.stubs(:to_hash).returns(request.headers)
    request
  end

  def fake_session
    session = stub
    session.stubs(:to_hash).returns({"one" => 1, "two" => 2})
    session
  end

  def fake_error
    begin; raise "This is an error."; rescue Exception => e; e; end
  end

  def parse_schema
    xsd = IO.read(SCHEMA_PATH)
    Nokogiri::XML::Schema.new(xsd)
  end

  context "upon creation" do
    setup do
      @notice = make_new_notice
    end

    should "contain the api key" do
      assert_equal HoptoadNotifier.api_key, @notice.api_key
    end

    should "contain the environment" do
      ENV.keys.each do |key|
        assert_equal ENV[key], @notice.server_environment[key]
      end
    end

    should "contain the project root" do
      assert_equal File.expand_path(RAILS_ROOT), @notice.project_root
    end

    should "contain the environment name" do
      assert_equal RAILS_ENV, @notice.environment_name
    end

    should "contain the notifier name" do
      assert_equal HoptoadNotifier::NAME, @notice.notifier_name
    end

    should "contain the notifier version" do
      assert_equal HoptoadNotifier::VERSION, @notice.notifier_version
    end

    should "contain the notifier url" do
      assert_equal HoptoadNotifier::URL, @notice.notifier_url
    end

    should "contain the backtrace" do
      assert_equal __FILE__, @notice.error_backtrace.first['file']
      assert_equal '8', @notice.error_backtrace.first['number']
      assert_match %r{make_new_notice}, @notice.error_backtrace.first['method']
    end
  end

  context "when assigned a request" do
    setup do
      @request = fake_request
      @notice = HoptoadNotifier::Notice.new
      @notice.request = @request
    end

    should "set the controller" do
      assert_equal "users", @notice.request_controller
    end

    should "set the action" do
      assert_equal "create", @notice.request_action
    end

    should "set the url" do
      assert_equal "https://test.host/users/?something=awesome", @notice.request_url
    end

    should "set the parameters" do
      @request.parameters.keys.each do |key|
        assert_equal @request.parameters[key], @notice.request_parameters[key]
      end
    end

    should "set the headers" do
      @request.headers.keys.each do |key|
        assert_equal @request.headers[key], @notice.request_headers[key]
      end
    end
  end

  context "when assigned a session" do
    setup do
      @session = fake_session
      @notice = HoptoadNotifier::Notice.new
      @notice.session = @session
    end

    should "set the data" do
      @session.to_hash.keys.each do |key|
        assert_equal @session.to_hash[key], @notice.request_session[key]
      end
    end
  end

  context "when assigned an error" do
    setup do
      @error = fake_error
      @notice = HoptoadNotifier::Notice.new
      @notice.error = @error
    end

    should "set the error class" do
      assert_equal "RuntimeError", @notice.error_class
    end

    should "set the error message" do
      assert_equal "This is an error.", @notice.error_message
    end

    should "set the backtrace" do
      assert_equal __FILE__, @notice.error_backtrace.first['file']
      @notice.error_backtrace.first
    end
  end

  context "when assigned error info manually" do
    setup do
      @notice = HoptoadNotifier::Notice.new
      @notice.error_class = "Not RuntimeError"
      @notice.error_message = "Something Happened."
    end

    should "set the error class" do
      assert_equal "Not RuntimeError", @notice.error_class
    end

    should "set the error message" do
      assert_equal "Something Happened.", @notice.error_message
    end
  end

  def assert_valid_notifier_xml(xml)
    errors = parse_schema.validate(Nokogiri::XML::Document.parse(xml))
    assert errors.empty?, errors.collect(&:message).join
  end

  context "a populated Notice" do
    setup do
      @notice = HoptoadNotifier::Notice.new
      @notice.request = fake_request
      @notice.session = fake_session
      @notice.error = fake_error
    end

    should "return XML that validates against the schema" do
      assert_valid_notifier_xml(@notice.to_xml)
    end
  end
end
