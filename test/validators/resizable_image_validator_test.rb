require "test_helper"

class ResizableImageValidatorTest < ActiveSupport::TestCase
  test "a user can't save an avatar larger than 5 MB" do
    user = users(:one)
    user.avatar.attach(
      io: StringIO.new("x" * (5.megabytes + 1)),
      filename: "oversized-avatar.png",
      content_type: "image/png"
    )

    assert_not user.valid?
    assert_includes user.errors[:avatar], "must be smaller than 5 MB"
  end

  test "a family can't save an oversized avatar" do
    account = accounts(:one)
    account.avatar.attach(
      io: StringIO.new("x" * (5.megabytes + 1)),
      filename: "oversized-avatar.png",
      content_type: "image/png"
    )

    assert_not account.valid?
    assert_includes account.errors[:avatar], "must be smaller than 5 MB"
  end

  test "a normal-size PNG avatar is still valid" do
    user = users(:one)
    user.avatar.attach(
      io: StringIO.new(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL1EAAAAABJRU5ErkJggg==")),
      filename: "avatar.png",
      content_type: "image/png"
    )

    assert_predicate user, :valid?
  end
end
