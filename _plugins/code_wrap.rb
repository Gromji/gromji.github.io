module Jekyll
  module CodeWrapFilter
    def code_wrap(input, css_class)
      Jekyll.logger.info "code_wrap called with css_class:", css_class

      if css_class.to_s.empty?
        "<code style=\"border: none\">#{input}</code>"
      else
        "<code style=\"border: none\" class=\"#{css_class}\">#{input}</code>"
      end
    end
  end
end

Liquid::Template.register_filter(Jekyll::CodeWrapFilter)
