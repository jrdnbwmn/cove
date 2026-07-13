module SvgHelper
  def render_svg(name, options = {})
    if (asset_path = Rails.application.assets.load_path.find("#{name}.svg"))
      document = File.open(asset_path.path) { Nokogiri::XML(it) }

      svg = document.at_css("svg")
      svg.search("title").each { it.remove }
      svg.prepend_child(document.create_element("title", name.underscore.humanize))

      svg["role"] = "img"
      svg["class"] = safe_join((svg["class"] || "").split(" ") + Array.wrap(options.fetch(:class, "fill-current")), " ")

      document.to_s.html_safe
    else
      raise NameError, "Unable to find SVG asset named: #{name}.svg"
    end
  end
end
