# frozen_string_literal: true

require "commonmarker"
require "rouge"
require "yard"

module CommonMarker
  class YARD
    class Document
      def initialize(text)
        @ast = ::CommonMarker.render_doc(text)

        @ast.walk { |node| highlight node if node.type == :code_block }
      end

      def to_html
        HtmlRenderer.new.render(@ast)
      end

      private

      def highlight(node)
        lexer     = ::Rouge::Lexer.find_fancy(node.fence_info) || ::Rouge::Lexers::PlainText.new
        formatter = ::Rouge::Formatters::HTML.new({})
        new_node  = ::CommonMarker::Node.new(:code_block)

        new_node.string_content = formatter.format(lexer.lex(node.string_content))

        node.insert_before(new_node)
        node.delete
      end
    end
  end
end

YARD::Templates::Helpers::MarkupHelper::MARKUP_PROVIDERS[:markdown] << {
  :lib   => :commonmarker,
  :const => "CommonMarker::YARD::Document"
}
