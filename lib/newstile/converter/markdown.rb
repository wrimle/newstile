# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2009-2010 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of newstile.
#
# newstile is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
#

require 'rexml/parsers/baseparser'

module Newstile

  module Converter

    # Converts a Newstile::Document to the newstile format.
    class Markdown < Base

      # :stopdoc:

      include ::Newstile::Utils::HTML

      def initialize(doc)
        super
        @linkrefs = []
        @footnotes = []
        @abbrevs = []
        @stack = []
      end

      def convert(el, opts = {:indent => 0})
        res = send("convert_#{el.type}", el, opts)
        if el.type != :html_element && el.type != :li && el.type != :dd && (ial = ial_for_element(el))
          res << ial
          res << "\n\n" if el.options[:category] == :block
        elsif [:ul, :dl, :ol, :codeblock].include?(el.type) && opts[:next] &&
            ([el.type, :codeblock].include?(opts[:next].type) ||
             (opts[:next].type == :blank && opts[:nnext] && [el.type, :codeblock].include?(opts[:nnext].type)))
          res << "^\n\n"
        elsif el.options[:category] == :block && ![:li, :dd, :dt, :td, :th, :tr, :thead, :tbody, :tfoot, :blank].include?(el.type) &&
            (el.type != :p || !el.options[:transparent])
          res << "\n"
        end
        res
      end

      def inner(el, opts = {:indent => 0})
        @stack.push(el)
        result = ''
        el.children.each_with_index do |inner_el, index|
          options = opts.dup
          options[:index] = index
          options[:prev] = (index == 0 ? nil : el.children[index-1])
          options[:pprev] = (index <= 1 ? nil : el.children[index-2])
          options[:next] = (index == el.children.length - 1 ? nil : el.children[index+1])
          options[:nnext] = (index >= el.children.length - 2 ? nil : el.children[index+2])
          result << convert(inner_el, options)
        end
        @stack.pop
        result
      end

      def convert_blank(el, opts)
        ""
      end

      ESCAPED_CHAR_RE = /(\$\$|[\\*_`\[\]\{"'])|^[ ]{0,3}(:)/

      def convert_text(el, opts)
        if opts[:raw_text]
          el.value
        else
          el.value.gsub(/\A\n/) do
            opts[:prev] && opts[:prev].type == :br ? '' : "\n"
          end.gsub(/\s+/, ' ').gsub(ESCAPED_CHAR_RE) { "\\#{$1 || $2}" }
        end
      end

      def convert_p(el, opts)
        w = @doc.options[:line_width] - opts[:indent].to_s.to_i
        first, second, *rest = inner(el, opts).strip.gsub(/(.{1,#{w}})( +|$\n?)/, "\\1\n").split(/\n/)
        first.gsub!(/^(?:(#)|(\d+)\.|([+-]\s))/) { $1 || $3 ? "\\#{$1 || $3}" : "#{$2}\\."}
        first.gsub!(/\|/, '\\|')
        second.gsub!(/^([=-]+\s*?)$/, "\\\1") if second
        [first, second, *rest].compact.join("\n") + "\n"
      end


      def convert_codeblock(el, opts)
        el.value.split(/\n/).map {|l| l.empty? ? "    " : "    #{l}"}.join("\n") + "\n"
      end

      def convert_blockquote(el, opts)
        opts[:indent] += 2
        inner(el, opts).chomp.split(/\n/).map {|l| "> #{l}"}.join("\n") << "\n"
      end

      def convert_header(el, opts)
        res = ''
        res << "#{'#' * el.options[:level]} #{inner(el, opts)}"
        res << "   {##{el.attr['id']}}" if el.attr['id']
        res << "\n"
      end

      def convert_hr(el, opts)
        "* * *\n"
      end

      def convert_ul(el, opts)
        inner(el, opts).sub(/\n+\Z/, "\n")
      end
      alias :convert_ol :convert_ul
      alias :convert_dl :convert_ul

      def convert_li(el, opts)
        sym, width = if @stack.last.type == :ul
                       ['* ', el.children.first.type == :codeblock ? 4 : 2]
                     else
                       ["#{opts[:index] + 1}.".ljust(4), 4]
                     end
        if ial = ial_for_element(el)
          sym += ial + " "
        end

        opts[:indent] += width
        text = inner(el, opts)
        newlines = text.scan(/\n*\Z/).first
        first, *last = text.split(/\n/)
        last = last.map {|l| " "*width + l}.join("\n")
        text = first + (last.empty? ? "" : "\n") + last + newlines
        if el.children.first.type == :p && !el.children.first.options[:transparent]
          res = "#{sym}#{text}"
          res << "^\n" if el.children.size == 1 && @stack.last.children.last == el &&
            (@stack.last.children.any? {|c| c.children.first.type != :p} || @stack.last.children.size == 1)
          res
        elsif el.children.first.type == :codeblock
          "#{sym}\n    #{text}"
        else
          "#{sym}#{text}"
        end
      end

      def convert_dd(el, opts)
        sym, width = ": ", (el.children.first.type == :codeblock ? 4 : 2)
        if ial = ial_for_element(el)
          sym += ial + " "
        end

        opts[:indent] += width
        text = inner(el, opts)
        newlines = text.scan(/\n*\Z/).first
        first, *last = text.split(/\n/)
        last = last.map {|l| " "*width + l}.join("\n")
        text = first + (last.empty? ? "" : "\n") + last + newlines
        text.chomp! if text =~ /\n\n\Z/ && opts[:next] && opts[:next].type == :dd
        text += "\n" if text !~ /\n\n\Z/ && opts[:next] && opts[:next].type == :dt
        if el.children.first.type == :p && !el.children.first.options[:transparent]
          "\n#{sym}#{text}"
        elsif el.children.first.type == :codeblock
          "#{sym}\n    #{text}"
        else
          "#{sym}#{text}"
        end
      end

      def convert_dt(el, opts)
        inner(el, opts) << "\n"
      end

      HTML_TAGS_WITH_BODY=['div', 'script', 'iframe', 'textarea']

      def convert_html_element(el, opts)
        markdown_attr = el.options[:category] == :block && el.children.any? do |c|
          c.type != :html_element && (c.type != :p || !c.options[:transparent]) && c.options[:category] == :block
        end
        opts[:force_raw_text] = true if %w{script pre code}.include?(el.value)
        opts[:raw_text] = opts[:force_raw_text] || opts[:block_raw_text] || (el.options[:category] != :span && !markdown_attr)
        opts[:block_raw_text] = true if el.options[:category] == :block && opts[:raw_text]
        res = inner(el, opts)
        if el.options[:category] == :span
          "<#{el.value}#{html_attributes(el)}" << (!res.empty? || HTML_TAGS_WITH_BODY.include?(el.value) ? ">#{res}</#{el.value}>" : " />")
        else
          output = ''
          output << "<#{el.value}#{html_attributes(el)}"
          output << " markdown=\"1\"" if markdown_attr
          if !res.empty? && el.options[:parse_type] != :block
            output << ">#{res}</#{el.value}>"
          elsif !res.empty?
            output << ">\n#{res}"  <<  "</#{el.value}>"
          elsif HTML_TAGS_WITH_BODY.include?(el.value)
            output << "></#{el.value}>"
          else
            output << " />"
          end
          output << "\n" if @stack.last.type != :html_element || @stack.last.options[:parse_type] != :raw
          output
        end
      end

      def convert_xml_comment(el, opts)
        if el.options[:category] == :block && (@stack.last.type != :html_element || @stack.last.options[:parse_type] != :raw)
          el.value + "\n"
        else
          el.value
        end
      end
      alias :convert_xml_pi :convert_xml_comment
      alias :convert_html_doctype :convert_xml_comment

      def convert_table(el, opts)
        opts[:alignment] = el.options[:alignment]
        inner(el, opts)
      end

      def convert_thead(el, opts)
        rows = inner(el, opts)
        if opts[:alignment].all? {|a| a == :default}
          "#{rows}|" + "-"*10 + "\n"
        else
          "#{rows}| " + opts[:alignment].map do |a|
            case a
            when :left then ":-"
            when :right then "-:"
            when :center then ":-:"
            when :default then "-"
            end
          end.join(' ') + "\n"
        end
      end

      def convert_tbody(el, opts)
        res = ''
        res << inner(el, opts)
        res << '|' << '-'*10 << "\n" if opts[:next] && opts[:next].type == :tbody
        res
      end

      def convert_tfoot(el, opts)
        "|" + "="*10 + "\n#{inner(el, opts)}"
      end

      def convert_tr(el, opts)
        "| " + el.children.map {|c| convert(c, opts)}.join(" | ") + " |\n"
      end

      def convert_td(el, opts)
        inner(el, opts).gsub(/\|/, '\\|')
      end
      alias :convert_th :convert_td

      def convert_comment(el, opts)
        if el.options[:category] == :block
          "{::comment}\n#{el.value}\n{:/}\n"
        else
          "{::comment}#{el.value}{:/}"
        end
      end

      def convert_br(el, opts)
        "  \n"
      end

      def convert_a(el, opts)
        if el.attr['href'].empty?
          "[#{inner(el, opts)}]()"
        elsif el.attr['href'] =~ /^(?:http|ftp)/ || el.attr['href'].count("()") > 0
          index = if link_el = @linkrefs.find {|c| c.attr['href'] == el.attr['href']}
                    @linkrefs.index(link_el) + 1
                  else
                    @linkrefs << el
                    @linkrefs.size
                  end
          "[#{inner(el, opts)}][#{index}]"
        else
          title = el.attr['title'].to_s.empty? ? '' : ' "' + el.attr['title'].gsub(/"/, "&quot;") + '"'
          "[#{inner(el, opts)}](#{el.attr['href']}#{title})"
        end
      end

      def convert_img(el, opts)
        if el.attr['src'].empty?
          "![#{el.attr['alt']}]()"
        else
          title = (el.attr['title'] ? ' "' + el.attr['title'].gsub(/"/, "&quot;") + '"' : '')
          link = if el.attr['src'].count("()") > 0
                   "<#{el.attr['src']}>"
                 else
                   el.attr['src']
                 end
          "![#{el.attr['alt']}](#{link}#{title})"
        end
      end

      def convert_codespan(el, opts)
        delim = (el.value.scan(/`+/).max || '') + '`'
        "#{delim}#{' ' if delim.size > 1}#{el.value}#{' ' if delim.size > 1}#{delim}"
      end

      def convert_footnote(el, opts)
        @footnotes << [el.options[:name], @doc.parse_infos[:footnotes][el.options[:name]]]
        "[^#{el.options[:name]}]"
      end

      def convert_raw(el, opts)
        attr = (el.options[:type] || []).join(' ')
        attr = " type=\"#{attr}\"" if attr.length > 0
        if @stack.last.type == :html_element
          el.value
        elsif el.options[:category] == :block
          "{::nomarkdown#{attr}}\n#{el.value}\n{:/}\n"
        else
          "{::nomarkdown#{attr}}#{el.value}{:/}"
        end
      end

      def convert_em(el, opts)
        "*#{inner(el, opts)}*"
      end

      def convert_strong(el, opts)
        "**#{inner(el, opts)}**"
      end

      def convert_entity(el, opts)
        entity_to_str(el.value, el.options[:original])
      end

      TYPOGRAPHIC_SYMS = {
        :mdash => '---', :ndash => '--', :qdash_space => '-- ', :qdash => '--', :hellip => '...',
        :laquo_space => '<< ', :raquo_space => ' >>',
        :laquo => '<<', :raquo => '>>'
      }
      def convert_typographic_sym(el, opts)
        TYPOGRAPHIC_SYMS[el.value]
      end

      def convert_smart_quote(el, opts)
        el.value.to_s =~ /[rl]dquo/ ? "\"" : "'"
      end

      def convert_math(el, opts)
        (@stack.last.type == :p && opts[:prev].nil? ? "\\" : '') + "$$#{el.value}$$" + (el.options[:category] == :block ? "\n" : '')
      end

      def convert_abbreviation(el, opts)
        el.value
      end

      def convert_root(el, opts)
        res = inner(el, opts)
        res << create_link_defs
        res << create_footnote_defs
        res << create_abbrev_defs
        res
      end

      def create_link_defs
        res = ''
        res << "\n\n" if @linkrefs.size > 0
        @linkrefs.each_with_index do |el, i|
          title = el.attr['title']
          res << "[#{i+1}]: #{el.attr['href']} #{title ? '"' + title.gsub(/"/, "&quot;") + '"' : ''}\n"
        end
        res
      end

      def create_footnote_defs
        res = ''
        @footnotes.each do |name, data|
          res << "[^#{name}]:\n"
          res << inner(data[:content]).chomp.split(/\n/).map {|l| "    #{l}"}.join("\n") + "\n\n"
        end
        res
      end

      def create_abbrev_defs
        return '' unless @doc.parse_infos[:abbrev_defs]
        res = ''
        @doc.parse_infos[:abbrev_defs].each do |name, text|
          res << "*[#{name}]: #{text}\n"
        end
        res
      end

      # Return the IAL containing the attributes of the element +el+.
      def ial_for_element(el)
        res = el.attr.map do |k,v|
          next if [:img, :a].include?(el.type) && ['href', 'src', 'alt', 'title'].include?(k)
          next if el.type == :header && k == 'id'
          if v.nil?
            ''
          elsif k == 'class'
            " " + v.split(/\s+/).map {|w| ".#{w}"}.join(" ")
          elsif k == 'id'
            " ##{v}"
          else
            " #{k}=\"#{v.to_s}\""
          end
        end.compact.join('')
        res = "toc" + (res.strip.empty? ? '' : " #{res}") if (el.type == :ul || el.type == :ol) &&
          (el.options[:ial][:refs].include?('toc') rescue nil)
        res.strip.empty? ? nil : "{:#{res}}"
      end

    end

  end
end
