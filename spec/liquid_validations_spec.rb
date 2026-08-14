require_relative "spec_helper"

class Mixin < ActiveRecord::Base
end

describe LiquidValidations do
  it "should provide the validates_liquid_of method to ActiveRecord subclasses" do
    _(Mixin).must_respond_to(:validates_liquid_of)
  end

  it "should provide the validates_presence_of_liquid_variable method to ActiveRecord subclasses" do
    _(Mixin).must_respond_to(:validates_presence_of_liquid_variable)
  end

  it "should provide the validates_liquid_tag method to ActiveRecord subclasses" do
    _(Mixin).must_respond_to(:validates_liquid_tag)
  end

  describe ".validates_liquid_of" do
    before do
      Mixin.instance_eval do
        validates_liquid_of :content
      end

      @mixin = Mixin.new
      @mixin.errors.clear
    end

    [" {{ Bad liquid ",
     " {% Bad liquid ",
     "{% for %}{% endfor"].each do |bad_liquid|
      it "the record should be invalid when there is a liquid parsing error for #{bad_liquid}" do
        @mixin.content = bad_liquid
        _(@mixin.valid?).must_equal false
      end
    end

    it "should include the errors in the errors object" do
      @mixin.content = "{{ unclosed variable "
      @mixin.valid?
      _(@mixin.errors.full_messages.any? { |e| e == "Content syntax error: Variable '{{' was not properly closed" }).must_equal true
    end

    it "should add the errors to the validated attribute, not to base" do
      @mixin.content = "{{ unclosed variable "
      @mixin.valid?
      _(@mixin.errors[:content]).wont_be_empty
      _(@mixin.errors[:base]).must_be_empty
    end
  end

  describe ".validates_presence_of_liquid_variable" do
    before do
      Mixin.instance_eval do
        validates_presence_of_liquid_variable :content, :variable => "josh_is_awesome"
      end

      @mixin = Mixin.new
    end

    it "must be configured properly" do
      _(proc { Mixin.instance_eval { validates_presence_of_liquid_variable :content } }).must_raise ArgumentError
    end

    it "the record should be invalid when the specified variable is not present" do
      @mixin.content = "{{ josh_is_not_awesome }}"
      _(@mixin.valid?).must_equal false
    end

    it "should include the errors in the errors object" do
      @mixin.content = "{{ josh_is_not_awesome }}"
      @mixin.valid?
      _(@mixin.errors.full_messages.any? { |e| e == "Content must include {{ josh_is_awesome }}" }).must_equal true
    end

    it "should add the errors to the validated attribute, not to base" do
      @mixin.content = "{{ josh_is_not_awesome }}"
      @mixin.valid?
      _(@mixin.errors[:content]).wont_be_empty
      _(@mixin.errors[:base]).must_be_empty
    end
  end

  describe ".validates_liquid_tag" do
    describe "When presence is a proc" do
      before do
        # proc = Proc.new { self.verification_method == "sms" }
        Mixin.instance_eval do
          validates_liquid_tag :content, :tag => ["Joh", "meshu@gmail.com", "2518063"], max: 2, presence: ->(user) { user.verification_method == "sms" }, if: :verification_method?
        end
        @mixin = Mixin.new
        p Mixin.column_names
      end
      it "must be valid when the content is nil" do
        @mixin.content = nil
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% Joh %}{% meshu@gmail.com %}{% 2518063 %}" }).must_equal false
      end
      it "must be valid when the content is Joh" do
        @mixin.content = "{% Joh %}{% meshu@gmail.com %}{% 2518063 %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% Joh %}{% meshu@gmail.com %}{% 2518063 %}" }).must_equal false
      end
      it "must be invalid when the content is nil and the verification_method is sms" do
        @mixin.content = nil
        @mixin.verification_method = "sms"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% Joh %}{% meshu@gmail.com %}{% 2518063 %}" }).must_equal true
      end

      it "must be invalid when the verification_method is email" do
        @mixin.content = "{% Joh %}{% meshu@gmail.com %}{% 2518063 %}"
        @mixin.verification_method = "email"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% Joh %}{% meshu@gmail.com %}{% 2518063 %}" }).must_equal false
      end
    end
    describe "When tag contanis array of tag and presence is false" do
      before do
        Mixin.instance_eval do
          validates_liquid_tag :content, :tag => ["Joh", "meshu@gmail.com", "2518063"], max: 2, presence: false
        end
        @mixin = Mixin.new
      end
      it "must be valid when the content is nil" do
        @mixin.content = nil
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must not have more than 2 {% Joh %}" }).must_equal false
      end

      it "must be valid when we include all tags in our content" do
        @mixin.content = "{% Joh %} {% Joh %} {% meshu@gmail.com %} {% 2518063 %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% Joh %}{% meshu@gmail.com %}{% 2518063 %}" }).must_equal false
      end

      it "must be invalid when tag is greater than max count" do
        @mixin.content = "{% Joh %} {% Joh %} {% Joh %} {% meshu@gmail.com %} {% 2518063 %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must not have more than 2 {% Joh %}" }).must_equal true
      end
    end
    describe "When tag contanis array of tag and presence is true" do
      before do
        Mixin.instance_eval do
          validates_liquid_tag :content, :tag => ["meshu", "meshu@gmail.com", "2518063"], max: 2
        end
        @mixin = Mixin.new
      end
      it "must be invalid when we didn't include all tags in our content" do
        @mixin.content = "{% meshu %} {% meshu@gmail.com %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% meshu %}{% meshu@gmail.com %}{% 2518063 %}" }).must_equal true
      end

      it "must be valid when we include all tags in our content" do
        @mixin.content = "{% meshu %} {% meshu@gmail.com %} {% 2518063 %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% meshu %}{% meshu@gmail.com %}{% 2518063 %}" }).must_equal false
      end

      it "must be valid when we include all tags in our content" do
        @mixin.content = "{% meshu %} {% meshu %} {% meshu@gmail.com %} {% 2518063 %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% meshu %}{% meshu@gmail.com %}{% 2518063 %}" }).must_equal false
      end

      it "must be invalid when tag is greater than max count" do
        @mixin.content = "{% meshu %} {% meshu %} {% meshu %} {% meshu@gmail.com %} {% 2518063 %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must not have more than 2 {% meshu %}" }).must_equal true
      end
    end
    describe "When tag presence is false" do
      before do
        Mixin.instance_eval do
          validates_liquid_tag :content, :tag => "john_is_awesome", presence: false, max: 2
        end
        @mixin = Mixin.new
      end
      it "must be valid if there is no tag" do
        _(proc { Mixin.instance_eval { validates_liquid_tag :content, presence: false } }).must_be_silent
      end

      it "must be invalid when tag is greater than max count" do
        @mixin.content = "{% john_is_awesome %} {% john_is_awesome %} {% john_is_awesome %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must not have more than 2 {% john_is_awesome %}" }).must_equal true
      end

      it "must be valid when tag less than max" do
        @mixin.content = "{% john_is_awesome %} "
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% john_is_awesome %}" }).must_equal false
      end

      it "must be valid when the content does not include the tag" do
        @mixin.content = "{% name %} "
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% john_is_awesome %}" }).must_equal false
      end

      it "must be valid when the content is nil" do
        @mixin.content = nil
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% john_is_awesome %}" }).must_equal false
      end

      it "must be valid when tag equal to max" do
        @mixin.content = "{% john_is_awesome %} {% john_is_awesome %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% john_is_awesome %}" }).must_equal false
      end
    end
    describe "When tag presence is true by default" do
      before do
        Mixin.instance_eval do
          validates_liquid_tag :content, :tag => "josh_is_awesome", max: 2
        end
        @mixin = Mixin.new
      end

      it "must be configured properly" do
        _(proc { Mixin.instance_eval { validates_liquid_tag :content, :tag => "josh_is_awesome" } }).must_raise ArgumentError
      end

      it "must be configured properly" do
        _(proc { Mixin.instance_eval { validates_liquid_tag :content } }).must_raise ArgumentError
      end

      it "should include the errors in the errors object" do
        @mixin.content = "josh_is_awesome"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% josh_is_awesome %}" }).must_equal true
      end

      it "must be valid when include tag" do
        @mixin.content = "{% josh_is_awesome %} "
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% josh_is_awesome %}" }).must_equal false
      end

      it "must be valid when using more complex tag" do
        @mixin.content = "{% josh_is_awesome foobar, data-required='true' %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% josh_is_awesome %}" }).must_equal false
      end

      it "must be invalid when using tag like { josh_is_awesome }" do
        @mixin.content = "{ josh_is_awesome }"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% josh_is_awesome %}" }).must_equal true
      end

      it "must be invalid when using tag like {% josh_is_awesome }" do
        @mixin.content = "{% josh_is_awesome }"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% josh_is_awesome %}" }).must_equal true
      end

      it "must be invalid when using tag like { josh_is_awesome %}" do
        @mixin.content = "{ josh_is_awesome %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% josh_is_awesome %}" }).must_equal true
      end

      it "must be invalid when using tag like {%% josh_is_awesome %%}" do
        @mixin.content = "{%% josh_is_awesome %%}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% josh_is_awesome %}" }).must_equal true
      end

      it "must be invalid when using tag like %{ josh_is_awesome }%" do
        @mixin.content = "%{ josh_is_awesome }%"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% josh_is_awesome %}" }).must_equal true
      end

      it "must be invalid when using tag like empty content" do
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must include {% josh_is_awesome %}" }).must_equal true
      end

      it "must be valid when tag like {% josh_is_awesome %} {% josh_is_awesome %} {% josh_is_" do
        @mixin.content = "{% josh_is_awesome %} {% josh_is_awesome %} {% josh_is_"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must not have more than 2 {% josh_is_awesome %}" }).must_equal false
      end

      it "must be invalid when tag is greater than max count" do
        @mixin.content = "{% josh_is_awesome %} {% josh_is_awesome %} {% josh_is_awesome %}"
        @mixin.valid?
        _(@mixin.errors.full_messages.any? { |e| e == "Content must not have more than 2 {% josh_is_awesome %}" }).must_equal true
      end
    end
  end
end
