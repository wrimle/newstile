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

module Newstile
  module Parser
    class Newstile

      TYPOGRAPHIC_SYMS = [['---', :mdash], ['--', :ndash], 
                          ['-. ', :qdash_space], ['- ', :qdash_space],  
                          ['...', :hellip],
                          ['\\<<', '&lt;&lt;'], ['\\>>', '&gt;&gt;'],
                          ['<< ', :laquo_space], [' >>', :raquo_space],
                          ['<<', :laquo], ['>>', :raquo]]
      TYPOGRAPHIC_SYMS_SUBST = Hash[*TYPOGRAPHIC_SYMS.flatten]
      TYPOGRAPHIC_SYMS_RE = /#{TYPOGRAPHIC_SYMS.map {|k,v| Regexp.escape(k)}.join('|')}/

      # Parse the typographic symbols at the current location.
      def parse_typographic_syms
        @src.pos += @src.matched_size
        val = TYPOGRAPHIC_SYMS_SUBST[@src.matched]
        if val.kind_of?(Symbol)
          @tree.children << Element.new(:typographic_sym, val)
        elsif @src.matched == '\\<<'
          @tree.children << Element.new(:entity, ::Newstile::Utils::Entities.entity('lt'))
          @tree.children << Element.new(:entity, ::Newstile::Utils::Entities.entity('lt'))
        else
          @tree.children << Element.new(:entity, ::Newstile::Utils::Entities.entity('gt'))
          @tree.children << Element.new(:entity, ::Newstile::Utils::Entities.entity('gt'))
        end
      end
      define_parser(:typographic_syms, TYPOGRAPHIC_SYMS_RE, '-.|--|\\.\\.\\.|(?:\\\\| )?(?:<<|>>)')

    end
  end
end
