################################################################################
#
# Copyright (C) 2006 Peter J Jones (pjones@pmade.com)
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
################################################################################
require 'stringio'

class PDF::Reader
  ################################################################################
  # Walks the PDF file and calls the appropriate callback methods when something of interest is
  # found.
  #
  # The callback methods should exist on the receiver object passed into the constructor. Whenever
  # some content is found that will trigger a callback, the receiver is checked to see if the callback
  # is defined.
  #
  # If it is defined it will be called. If not, processing will continue.
  #
  # = Available Callbacks
  # The following callbacks are available and should be methods defined on your receiver class. Only
  # implement the ones you need - the rest will be ignored.
  #
  # Some callbacks will include parameters which will be passed in as an array. For callbacks that supply no
  # paramters, or where you don't need them, the *params argument can be left off. Some example callback
  # method definitions are:
  #
  #   def begin_document
  #   def end_page
  #   def show_text(string, *params)
  #   def fill_stroke(*params)
  #
  # You should be able to infer the basic command the callback is reporting based on the name. For
  # further experimentation, define the callback with just a *params parameter, then print out the
  # contents of the array using something like:
  #
  #   puts params.inspect
  #
  # == Text Callbacks
  #
  # All text passed into these callbacks will be encoded as UTF-8. Depending on where (and when) the
  # PDF was generated, there's a good chance the text is NOT stored as UTF-8 internally so be careful
  # when doing a comparison on strings returned from PDF::Reader (when doing unit tests for example). The
  # string may not be byte-by-byte identical with the string that was originally written to the PDF.
  #
  # - end_text_object
  # - move_to_start_of_next_line
  # - set_character_spacing
  # - move_text_position
  # - move_text_position_and_set_leading
  # - set_text_font_and_size
  # - show_text
  # - show_text_with_positioning
  # - set_text_leading
  # - set_text_matrix_and_text_line_matrix
  # - set_text_rendering_mode
  # - set_text_rise
  # - set_word_spacing
  # - set_horizontal_text_scaling
  # - move_to_next_line_and_show_text
  # - set_spacing_next_line_show_text
  #
  # == Graphics Callbacks
  # - close_fill_stroke
  # - fill_stroke
  # - close_fill_stroke_with_even_odd
  # - fill_stroke_with_even_odd
  # - begin_marked_content_with_pl
  # - begin_inline_image
  # - begin_marked_content
  # - begin_text_object
  # - append_curved_segment
  # - concatenate_matrix
  # - set_stroke_color_space
  # - set_nonstroke_color_space
  # - set_line_dash
  # - set_glyph_width
  # - set_glyph_width_and_bounding_box
  # - invoke_xobject
  # - define_marked_content_with_pl
  # - end_inline_image
  # - end_marked_content
  # - fill_path_with_nonzero
  # - fill_path_with_nonzero
  # - fill_path_with_even_odd
  # - set_gray_for_stroking
  # - set_gray_for_nonstroking
  # - set_graphics_state_parameters
  # - close_subpath
  # - set_flatness_tolerance
  # - begin_inline_image_data
  # - set_line_join_style
  # - set_line_cap_style
  # - set_cmyk_color_for_stroking,
  # - set_cmyk_color_for_nonstroking
  # - append_line
  # - begin_new_subpath
  # - set_miter_limit
  # - define_marked_content_point
  # - end_path
  # - save_graphics_state
  # - restore_graphics_state
  # - append_rectangle
  # - set_rgb_color_for_stroking
  # - set_rgb_color_for_nonstroking
  # - set_color_rendering_intent
  # - close_and_stroke_path
  # - stroke_path
  # - set_color_for_stroking
  # - set_color_for_nonstroking
  # - set_color_for_stroking_and_special
  # - set_color_for_nonstroking_and_special
  # - paint_area_with_shading_pattern
  # - append_curved_segment_initial_point_replicated
  # - set_line_width
  # - set_clipping_path_with_nonzero
  # - set_clipping_path_with_even_odd
  # - append_curved_segment_final_point_replicated
  #
  # == Misc Callbacks
  # - begin_compatibility_section
  # - end_compatibility_section,
  # - begin_document
  # - end_document
  # - begin_page_container
  # - end_page_container
  # - begin_page
  # - end_page
  # - metadata
  # - xml_metadata
  # - page_count
  # - begin_form_xobject
  # - end_form_xobject
  #
  # == Resource Callbacks
  #
  # Each page can contain (or inherit) a range of resources required for the page,
  # including things like fonts and images. The following callbacks may appear
  # after begin_page if the relevant resources exist on a page:
  #
  # - resource_procset
  # - resource_xobject
  # - resource_extgstate
  # - resource_colorspace
  # - resource_pattern
  # - resource_font
  #
  # In most cases, these callbacks associate a name with each resource, allowing it
  # to be referred to by name in the page content. For example, an XObject can hold an image.
  # If it gets mapped to the name "IM1", then it can be placed on the page using
  # invoke_xobject "IM1".
  #
  class Content
    OPERATORS = {
      'b'   => :close_fill_stroke,
      'B'   => :fill_stroke,
      'b*'  => :close_fill_stroke_with_even_odd,
      'B*'  => :fill_stroke_with_even_odd,
      'BDC' => :begin_marked_content_with_pl,
      'BI'  => :begin_inline_image,
      'BMC' => :begin_marked_content,
      'BT'  => :begin_text_object,
      'BX'  => :begin_compatibility_section,
      'c'   => :append_curved_segment,
      'cm'  => :concatenate_matrix,
      'CS'  => :set_stroke_color_space,
      'cs'  => :set_nonstroke_color_space,
      'd'   => :set_line_dash,
      'd0'  => :set_glyph_width,
      'd1'  => :set_glyph_width_and_bounding_box,
      'Do'  => :invoke_xobject,
      'DP'  => :define_marked_content_with_pl,
      'EI'  => :end_inline_image,
      'EMC' => :end_marked_content,
      'ET'  => :end_text_object,
      'EX'  => :end_compatibility_section,
      'f'   => :fill_path_with_nonzero,
      'F'   => :fill_path_with_nonzero,
      'f*'  => :fill_path_with_even_odd,
      'G'   => :set_gray_for_stroking,
      'g'   => :set_gray_for_nonstroking,
      'gs'  => :set_graphics_state_parameters,
      'h'   => :close_subpath,
      'i'   => :set_flatness_tolerance,
      'ID'  => :begin_inline_image_data,
      'j'   => :set_line_join_style,
      'J'   => :set_line_cap_style,
      'K'   => :set_cmyk_color_for_stroking,
      'k'   => :set_cmyk_color_for_nonstroking,
      'l'   => :append_line,
      'm'   => :begin_new_subpath,
      'M'   => :set_miter_limit,
      'MP'  => :define_marked_content_point,
      'n'   => :end_path,
      'q'   => :save_graphics_state,
      'Q'   => :restore_graphics_state,
      're'  => :append_rectangle,
      'RG'  => :set_rgb_color_for_stroking,
      'rg'  => :set_rgb_color_for_nonstroking,
      'ri'  => :set_color_rendering_intent,
      's'   => :close_and_stroke_path,
      'S'   => :stroke_path,
      'SC'  => :set_color_for_stroking,
      'sc'  => :set_color_for_nonstroking,
      'SCN' => :set_color_for_stroking_and_special,
      'scn' => :set_color_for_nonstroking_and_special,
      'sh'  => :paint_area_with_shading_pattern,
      'T*'  => :move_to_start_of_next_line,
      'Tc'  => :set_character_spacing,
      'Td'  => :move_text_position,
      'TD'  => :move_text_position_and_set_leading,
      'Tf'  => :set_text_font_and_size,
      'Tj'  => :show_text,
      'TJ'  => :show_text_with_positioning,
      'TL'  => :set_text_leading,
      'Tm'  => :set_text_matrix_and_text_line_matrix,
      'Tr'  => :set_text_rendering_mode,
      'Ts'  => :set_text_rise,
      'Tw'  => :set_word_spacing,
      'Tz'  => :set_horizontal_text_scaling,
      'v'   => :append_curved_segment_initial_point_replicated,
      'w'   => :set_line_width,
      'W'   => :set_clipping_path_with_nonzero,
      'W*'  => :set_clipping_path_with_even_odd,
      'y'   => :append_curved_segment_final_point_replicated,
      '\''  => :move_to_next_line_and_show_text,
      '"'   => :set_spacing_next_line_show_text,
    }
    ################################################################################
    # Create a new PDF::Reader::Content object to process the contents of PDF file
    # - receiver - an object containing the required callback methods
    # - xref     - a PDF::Reader::Xref object that contains references to all the objects in a PDF file
    def initialize (receiver, xref)
      @receiver = receiver
      @xref     = xref
    end
    ################################################################################
    # Begin processing the document metadata
    def metadata (root, info)
      info = decode_strings(info)

      # may be useful to some people
      callback(:pdf_version, @xref.pdf_version)

      # ye olde metadata
      callback(:metadata, [info]) if info

      # new style xml metadata
      if root[:Metadata]
        stream = @xref.object(root[:Metadata])
        callback(:xml_metadata,stream.unfiltered_data)
      end

      # page count
      if (pages = @xref.object(root[:Pages]))
        if (count = @xref.object(pages[:Count]))
          callback(:page_count, count.to_i)
        end
      end
    end
    ################################################################################
    # Begin processing the document
    def document (root)
      callback(:begin_document, [root])
      walk_pages(@xref.object(root[:Pages]))
      callback(:end_document)
    end
    ################################################################################
    # Walk over all pages in the PDF file, calling the appropriate callbacks for each page and all
    # its content
    def walk_pages (page)

      # extract page content
      if page[:Type] == :Pages
        callback(:begin_page_container, [page])
        res = @xref.object(page[:Resources])
        resources.push res if res
        @xref.object(page[:Kids]).each {|child| walk_pages(@xref.object(child))}
        resources.pop if res
        callback(:end_page_container)
      elsif page[:Type] == :Page
        callback(:begin_page, [page])
        res = @xref.object(page[:Resources])
        resources.push res if res
        walk_resources(current_resources)

        if @xref.object(page[:Contents]).kind_of?(Array)
          contents = @xref.object(page[:Contents])
        else
          contents = [page[:Contents]]
        end

        fonts = font_hash_from_resources(current_resources)

        if page.has_key?(:Contents) and page[:Contents]
          contents.each do |content|
            obj = @xref.object(content)
            content_stream(obj, fonts)
          end 
        end

        resources.pop if res
        callback(:end_page)
      end
    end
    ################################################################################
    # Retreive the XObject for the supplied label and if it's a Form, walk it
    # like a regular page content stream.
    #
    def walk_xobject_form(label)
      xobjects = @xref.object(current_resources[:XObject]) || {}
      xobject  = @xref.object(xobjects[label])

      if xobject && xobject.hash[:Subtype] == :Form
        callback(:begin_form_xobject)
        resources = @xref.object(xobject.hash[:Resources])
        walk_resources(resources) if resources
        fonts = font_hash_from_resources(resources)
        content_stream(xobject, fonts)
        callback(:end_form_xobject)
      end
    end

    ################################################################################
    # Return a merged hash of all resources that are current. Pages, page and xobject
    #
    def current_resources
      hash = {}
      resources.each do |res|
        hash.merge!(res)
      end
      hash
    end
    ################################################################################
    # Reads a PDF content stream and calls all the appropriate callback methods for the operators
    # it contains
    def content_stream (instructions, fonts = {})
      instructions = instructions.unfiltered_data if instructions.kind_of?(PDF::Reader::Stream)
      buffer       = Buffer.new(StringIO.new(instructions))
      parser       = Parser.new(buffer, @xref)
      current_font = nil
      params       = []

      while (token = parser.parse_token(OPERATORS))
        if token.kind_of?(Token) and OPERATORS.has_key?(token)
          current_font = params.first if OPERATORS[token] == :set_text_font_and_size

          # handle special cases in response to certain operators
          if OPERATORS[token].to_s.include?("show_text") && fonts[current_font]
            # convert any text to utf-8
            params = fonts[current_font].to_utf8(params)
          elsif token == "ID"
            # inline image data, first convert the current params into a more familiar hash
            map = {}
            params.each_slice(2) do |a|
              map[a.first] = a.last
            end
            params = [map]
            # read the raw image data from the buffer without tokenising
            params << buffer.read_until("EI")
          end

          callback(OPERATORS[token], params)

          if OPERATORS[token] == :invoke_xobject
            xobject_label = params.first
            params.clear
            walk_xobject_form(xobject_label)
          else
            params.clear
          end
        else
          params << token
        end
      end
    rescue EOFError => e
      raise MalformedPDFError, "End Of File while processing a content stream"
    end
    ################################################################################
    def walk_resources(resources)
      return unless resources.respond_to?(:[])

      resources = resolve_references(resources)

      # extract any procset information
      if resources[:ProcSet]
        callback(:resource_procset, resources[:ProcSet])
      end

      # extract any xobject information
      if resources[:XObject]
        @xref.object(resources[:XObject]).each do |name, val|
          callback(:resource_xobject, [name, @xref.object(val)])
        end
      end

      # extract any extgstate information
      if resources[:ExtGState]
        @xref.object(resources[:ExtGState]).each do |name, val|
          callback(:resource_extgstate, [name, @xref.object(val)])
        end
      end

      # extract any colorspace information
      if resources[:ColorSpace]
        @xref.object(resources[:ColorSpace]).each do |name, val|
          callback(:resource_colorspace, [name, @xref.object(val)])
        end
      end

      # extract any pattern information
      if resources[:Pattern]
        @xref.object(resources[:Pattern]).each do |name, val|
          callback(:resource_pattern, [name, @xref.object(val)])
        end
      end

      # extract any font information
      if resources[:Font]
        fonts = font_hash_from_resources(resources)
        fonts.each do  |label, font|
          callback(:resource_font, [label, font])
        end
      end
    end
    ################################################################################
    # Convert any PDF::Reader::Resource objects into a real object
    def resolve_references(obj)
      case obj
      when PDF::Reader::Stream then
        obj.hash = resolve_references(obj.hash)
        obj
      when PDF::Reader::Reference then
        resolve_references(@xref.object(obj))
      when Hash                   then obj.each { |key,val| obj[key] = resolve_references(val) }
      when Array                  then obj.collect { |item| resolve_references(item) }
      else
        obj
      end
    end
    ################################################################################
    # calls the name callback method on the receiver class with params as the arguments
    def callback (name, params=[])
      @receiver.send(name, *params) if @receiver.respond_to?(name)
    end
    ################################################################################
    private
    ################################################################################
    def font_hash_from_resources(resources)
      return {} unless resources.respond_to?(:[])

      fonts = {}
      resources = @xref.object(resources[:Font]) || {}
      resources.each do |label, desc|
        desc = @xref.object(desc)
        fonts[label] = PDF::Reader::Font.new
        fonts[label].label = label
        fonts[label].subtype = desc[:Subtype] if desc[:Subtype]
        fonts[label].basefont = desc[:BaseFont] if desc[:BaseFont]
        fonts[label].encoding = PDF::Reader::Encoding.new(@xref.object(desc[:Encoding]))
        fonts[label].descendantfonts = desc[:DescendantFonts] if desc[:DescendantFonts]
        if desc[:ToUnicode]
          # this stream is a cmap
          begin
            stream = desc[:ToUnicode]
            fonts[label].tounicode = PDF::Reader::CMap.new(stream.unfiltered_data)
          rescue
            # if the CMap fails to parse, don't worry too much. Means we can't translate the text properly
          end
        end
      end
      fonts
    end
    # strings outside of page content should be in either PDFDocEncoding or UTF-16.
    def decode_strings(obj)
      case obj
      when String then
        if obj[0,2] == "\376\377"
          PDF::Reader::Encoding.new(:UTF16Encoding).to_utf8(obj[2, obj.size])
        else
          PDF::Reader::Encoding.new(:PDFDocEncoding).to_utf8(obj)
        end
      when Hash   then obj.each { |key,val| obj[key] = decode_strings(val) }
      when Array  then obj.collect { |item| decode_strings(item) }
      else
        obj
      end
    end
    def resources
      @resources ||= []
    end
  end
  ################################################################################
end
################################################################################
