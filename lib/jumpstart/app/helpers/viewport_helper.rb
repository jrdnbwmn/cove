module ViewportHelper
  def viewport_meta_tag(content: "width=device-width, initial-scale=1", hotwire_native: "maximum-scale=1.0, user-scalable=0")
    full_content = [content, (hotwire_native if hotwire_native_app?)].compact.join(", ")
    tag.meta name: "viewport", content: full_content
  end
end
