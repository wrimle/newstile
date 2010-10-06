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

require 'newstile/compatibility'

require 'newstile/version'
require 'newstile/error'
require 'newstile/parser'
require 'newstile/converter'
require 'newstile/options'
require 'newstile/utils'

module Newstile

  # Return the data directory for newstile.
  def self.data_dir
    unless defined?(@@data_dir)
      require 'rbconfig'
      @@data_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'data', 'newstile'))
      @@data_dir = File.expand_path(File.join(Config::CONFIG["datadir"], "newstile")) if !File.exists?(@@data_dir)
      raise "newstile data directory not found! This is a bug, please report it!" unless File.directory?(@@data_dir)
    end
    @@data_dir
  end


  # The main interface to newstile.
  #
  # This class provides a one-stop-shop for using newstile to convert text into various output
  # formats. Use it like this:
  #
  #   require 'newstile'
  #   doc = Newstile::Document.new('This *is* some newstile text')
  #   puts doc.to_html
  #
  # The #to_html method is a shortcut for using the Converter::Html class.
  #
  # The second argument to the #new method is an options hash for customizing the behaviour of the
  # used parser and the converter. See Document#new for more information!
  class Document

    # The element tree of the document. It is immediately available after the #new method has been
    # called.
    attr_accessor :tree

    # The options hash which holds the options for parsing/converting the Newstile document. It is
    # possible that these values get changed during the parsing phase.
    attr_reader :options

    # An array of warning messages. It is filled with warnings during the parsing phase (i.e. in
    # #new) and the conversion phase.
    attr_reader :warnings

    # Holds needed parse information which is dependent on the used parser, like ALDs, link
    # definitions and so on. This information may be used by converters afterwards.
    attr_reader :parse_infos

    # Holds conversion information which is dependent on the used converter. A converter clears this
    # variable before doing the conversion.
    attr_reader :conversion_infos


    # Create a new Newstile document from the string +source+ and use the provided +options+. The
    # options that can be used are defined in the Options module.
    #
    # The special options key <tt>:input</tt> can be used to select the parser that should parse the
    # +source+. It has to be the name of a class in the Newstile::Parser module. For example, to
    # select the newstile parser, one would set the <tt>:input</tt> key to +Newstile+. If this key
    # is not set, it defaults to +Newstile+.
    #
    # The +source+ is immediately parsed by the selected parser so that the document tree is
    # immediately available and the output can be generated.
    def initialize(source, options = {})
      @options = Options.merge(options)
      @warnings = []
      @parse_infos = {}
      @parse_infos[:encoding] = source.encoding if RUBY_VERSION >= '1.9'
      @conversion_infos = {}
      parser = (options[:input] || 'newstile').to_s
      parser = parser[0..0].upcase + parser[1..-1]
      if Parser.const_defined?(parser)
        @tree = Parser.const_get(parser).parse(source, self)
      else
        raise Newstile::Error.new("newstile has no parser to handle the specified input format: #{options[:input]}")
      end
    end

    # Check if a method is invoked that begins with +to_+ and if so, try to instantiate a converter
    # class (i.e. a class in the Newstile::Converter module) and use it for converting the document.
    #
    # For example, +to_html+ would instantiate the Newstile::Converter::Html class.
    def method_missing(id, *attr, &block)
      if id.to_s =~ /^to_(\w+)$/
        Converter.const_get($1[0..0].upcase + $1[1..-1]).convert(self)
      else
        super
      end
    end

    def inspect #:nodoc:
      "<KD:Document: options=#{@options.inspect} tree=#{@tree.inspect} warnings=#{@warnings.inspect}>"
    end

  end


  # Represents all elements in the parse tree.
  #
  # newstile only uses this one class for representing all available elements in a parse tree
  # (paragraphs, headers, emphasis, ...). The type of element can be set via the #type accessor.
  class Element

    # A symbol representing the element type. For example, <tt>:p</tt> or <tt>:blockquote</tt>.
    attr_accessor :type

    # The value of the element. The interpretation of this field depends on the type of the element.
    # Many elements don't use this field.
    attr_accessor :value

    # The attributes of the element. Uses an Utils::OrderedHash to retain the insertion order.
    attr_reader :attr

    # The options hash for the element. It is used for storing arbitray options as well as the
    # following special contents:
    #
    # - Category of the element, either <tt>:block</tt> or <tt>:span</tt>, under the
    #   <tt>:category</tt> key. If this key is absent, it can be assumed that the element is in the
    #   <tt>:span</tt> category.
    attr_accessor :options

    # The child elements of this element.
    attr_accessor :children


    # Create a new Element object of type +type+. The optional parameters +value+, +attr+ and
    # +options+ can also be set in this constructor for convenience.
    def initialize(type, value = nil, attr = nil, options = {})
      @type, @value, @attr, @options = type, value, Utils::OrderedHash.new(attr), options
      @children = []
    end

    def inspect #:nodoc:
      "<kd:#{@type}#{@value.nil? ? '' : ' ' + @value.inspect} #{@attr.inspect}#{options.empty? ? '' : ' ' + @options.inspect}#{@children.empty? ? '' : ' ' + @children.inspect}>"
    end

  end

end

