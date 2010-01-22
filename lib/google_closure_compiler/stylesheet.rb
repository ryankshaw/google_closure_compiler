module GoogleClosureCompiler
  class Stylesheet

    def initialize(content)
      @content = content
    end

    def compressed
      @css_compressor = YUI::CssCompressor.new({
        :java => GoogleClosureCompiler.java_path
      })
      @css_compressor.compress(@content)
    end

  end # Stylesheet
end # GoogleClosureCompiler
