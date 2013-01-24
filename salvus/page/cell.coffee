######################################################
#
# A Compute Cell
#
######################################################

# imports
{EventEmitter} = require('events')

{copy, filename_extension, required, defaults, to_json} = require('misc')

{local_diff} = require('misc_page')



# templates
templates     = $("#salvus-cell-templates")
cell_template = templates.find(".salvus-cell")

# the Cell class
class Cell extends EventEmitter
    constructor: (opts={}) ->
        @opts = defaults opts,
            # DOM element (or jquery wrapped element); this is replaced by the cell
            element               : undefined

           # subarray of ['note','editor','output']; if given, hides
           # the given components when the cell is created
            hide                  : undefined

            # milliseconds interval between sending update change events about note
            note_change_timer     : 250
            # maximum height of note part of cell.
            note_max_height       : "auto"
            # initial value of the note (HTML)
            note_value            : undefined

            # language mode of the input editor
            editor_mode           : "python"
            # whether to display line numbers in the input code editor
            editor_line_numbers   : false
            # number of spaces to indent in the code editor
            editor_indent_spaces  : 4
            # whether or not to wrap lines in the code editor
            editor_line_wrapping  : true
            # undo depth for code editor
            editor_undo_depth     : 40
            # whether to do bracket matching in the code editor
            editor_match_brackets : true
            # css maximum height of code editor (scroll bars appear beyond this)
            editor_max_height     : "20em"
            # initial value of the code editor (TEXT)
            editor_value          : undefined

            # maximum height of output (scroll bars appear beyond this)
            output_max_height     : "20em"
            # whether or not to wrap lines in the output; if not wrapped, scrollbars appear
            output_line_wrapping  : false
            # initial value of the output area (JSON)
            output_value          : undefined
            # show output stopwatch during code evaluation.
            stopwatch             : true

            # a session -- needed to execute code in a cell
            session               : undefined

        if not @opts.element?
            @opts.element = $("<div>")

        e = $(@opts.element)

        if not @opts.editor_value?
            @opts.editor_value = e.text()

        @opts.note_value = e.data('note_value') if not @opts.note_value?
        @opts.output_value = e.data('output_value') if not @opts.output_value?

        @_note_change_timer_is_set = false

        @element = cell_template.clone()
        @_initialize_note()
        @_initialize_input()
        @_initialize_output()

        @element.data("cell", @)
        $(@opts.element).replaceWith(@element)

        @refresh()
        @_editor.setValue(@opts.editor_value)

        if @opts.hide?
            for e in @opts.hide
                @hide(e)

    #######################################################################
    # Private Methods
    #######################################################################

    _initialize_note: () ->
        # make note fire change event when changed
        @_note = @element.find(".salvus-cell-note")
        if @opts.note_value != ""
            @_note.html(@opts.note_value)
        @_note.css('max-height', @opts.note_max_height)
        that = @
        @_note.live('focus', ->
            $this = $(this)
            $this.data('before', $this.html())
        ).live('paste blur keyup', () ->
            if not that._note_change_timer_is_set
                that._note_change_timer_is_set = true
                setTimeout( (() ->
                    that._note_change_timer_is_set = false
                    before = that._note.data('before')
                    now    = that._note.html()
                    if before isnt now
                        that.emit('change', {'note':local_diff(before, now)})
                        that._note.data('before', now)
                    ),
                    that.opts.note_change_timer
                )
        )

    _initialize_input: () ->
        @_input = @element.find(".salvus-cell-input")
        @_initialize_code_editor()

    _initialize_code_editor: () ->
        that = @
        @_code_editor = @_input.find(".salvus-cell-editor")
        @_editor = CodeMirror.fromTextArea @_code_editor[0],
            firstLineNumber : 1
            autofocus       : false
            mode            : @opts.editor_mode
            lineNumbers     : @opts.editor_line_numbers
            indentUnit      : @opts.editor_indent_spaces
            tabSize         : @opts.editor_indent_spaces
            lineWrapping    : @opts.editor_line_wrapping
            undoDepth       : @opts.editor_undo_depth
            matchBrackets   : @opts.editor_match_brackets
            extraKeys       : {'Shift-Enter': () -> that.execute()}
        $(@_editor.getWrapperElement()).addClass('salvus-cell-editor')
        $(@_editor.getScrollerElement()).css('max-height' : @opts.editor_max_height)

        @_editor.on "change", (instance, changeObj) =>
            @emit "change", {editor:changeObj}
            @destroy_stopwatch()

        @_editor.on "focus", (e) =>
            @selected(true)
            @emit "focus"

        @_editor.on "blur", (e) =>
            @selected(false)
            @emit "blur"

    _initialize_output: ->
        @_output = @element.find(".salvus-cell-output")
        @_output.html(@opts.output_value)
        @_output.css('max-height', @opts.output_max_height)
        if @opts.output_line_wrapping
            @_output_line_wrapping_on()

    _output_line_wrapping_on: ->
        @_output.css
            'white-space'  : 'pre-wrap'
            'word-wrap'    : 'break-word'
            'overflow-wrap': 'break-word'

    _output_line_wrapping_off: ->
        @_output.removeClass('white-space word-wrap overflow-wrap')

    #######################################################################
    # Public API
    # Unless otherwise stated, these methods can be chained.
    #######################################################################

    start_stopwatch: () ->
        if @opts.stopwatch
            @element.find(".salvus-cell-stopwatch").addClass('salvus-cell-stopwatch-running'
            ).show().countdown('destroy').countdown(
                since   : new Date()
                compact : true
                layout  : '{hnn}{sep}{mnn}{sep}{snn}'
            ).click((e) -> @interrupt()).tooltip('destroy').tooltip(title:"Time running; click to interrupt.")

    stop_stopwatch: () ->
        if @opts.stopwatch
            @element.find(".salvus-cell-stopwatch").countdown('pause').removeClass('salvus-cell-stopwatch-running').tooltip('destroy').tooltip(title:"Time this took to run.")

    destroy_stopwatch: () ->
        if @opts.stopwatch
            @element.find(".salvus-cell-stopwatch").countdown('destroy').hide()

    append_to: (e) ->
        e.append(@element)
        return @

    # Refresh the cell; this might be needed if you hide the DOM element
    # that contains the editor, change it, then display it again.
    refresh: () ->
        @_editor.refresh()
        return @

    focus: ->
        @selected()
        @_editor.focus()
        @_editor.refresh()

    # Mark the cell as selected or not selected
    selected: (is_selected=true) ->
        if is_selected
            @_input.addClass("salvus-cell-input-selected")
        else
            @_input.removeClass("salvus-cell-input-selected")
        return @

    # Show an individual component of the cell:
    #
    #       cell.show("note"), cell.show("editor"), cell.show("output").
    #
    # Also, cell.show() will show the complete cell (not show each
    # component) if it was hidden; this does not impact which
    # components are hidden/shown.
    show: (e) ->
        if not e?
            @element.show()
            return
        switch e
            when 'note'
                @_note.show()
            when 'editor'
                $(@_editor.getWrapperElement()).show()
                @_editor.refresh()
            when 'output'
                @_output.show()
            else
                throw "unknown component #{e}"
        return @

    # Hide an individual component of the cell --
    #
    #  cell.hide("note"), cell.hide("editor"), cell.hide("output")
    #
    # Also, cell.hide() will hide the complete cell (not hide each
    # component); this does not impact which individual components are
    # hidden/shown.
    hide: (e) ->
        if not e?
            @element.hide()
            return
        switch e
            when 'note'
                @_note.hide()
            when 'editor'
                $(@_editor.getWrapperElement()).hide()
            when 'output'
                @_output.hide()
            else
                throw "unknown component #{e}"
        return @

    delete_output: () ->
        @_output.html('')

    # Append new output to one output stream of the cell
    append_output : (opts) ->
        opts = defaults opts,
            # the output stream: 'stdout', 'stderr', 'html', 'tex', 'file', 'javascript'
            stream : required
            # value -- options depends on the output stream:
            #     - stdout -- arbitrary text
            #     - stderr -- arbitrary text
            #     - html -- arbitrary valid html
            #     - tex -- {tex:'latex expression', display:true/false}   --  display math or inline math
            #     - file -- {filename:"...", uuid:"...", show:true/false}
            #     - javascript -- {code:"...", coffeescript:true/false}
            value  : required

        @emit("change", {output:opts})
        e = templates.find(".salvus-cell-output-#{opts.stream}").clone()
        if e.length != 1
            throw "ERROR -- missing template with class .salvus-cell-output-#{opts.stream}"
        @_output.append(e)
        switch opts.stream
            when 'stdout', 'stderr'
                e.text(opts.value)
            when 'html'
                e.html(opts.value)
            when 'tex'
                e.text(opts.value).data('value', opts.value).mathjax(
                                        tex: opts.value.tex, display:opts.value.display)
            when 'file'
                if opts.value.show
                    target = "/blobs/#{opts.value.filename}?uuid=#{opts.value.uuid}"
                    switch filename_extension(opts.value.filename)
                        # TODO: harden DOM creation below
                        when 'svg', 'png', 'gif', 'jpg'
                            e.append($("<img src='#{target}' class='salvus-cell-output-img'>"))
                        else
                            e.append($("<a href='#{target}' target='_new'>#{opts.value.filename} (this temporary link expires in a minute)</a> "))
            when 'javascript'
                if opts.value.coffeescript
                    eval(CoffeeScript.compile(opts.value.code))
                else
                    eval(opts.value.code)
            else
                throw "unknown stream '#{opts.stream}'"
        return @

    set_session: (session) ->
        @opts.session = session

    execute: () ->
        if not @opts.session
            throw "Attempt to execute code on a cell whose session has not been set."
        @emit('execute')
        first_message = true
        @opts.session.execute_code
            code     : @_editor.getValue()
            preparse : true
            cb       : (mesg) =>
                # NOTE: this callback function gets called
                # *repeatedly* while this cell is being evaluated.
                # The last message has the property that mesg.done is
                # true.  Right When the cell *starts* being evaluated
                # a mesg is always sent.
                if first_message
                    @delete_output()
                    first_message = false
                    @start_stopwatch()

                @append_output(stream:'stdout',     value:mesg.stdout)     if mesg.stdout?
                @append_output(stream:'stderr',     value:mesg.stderr)     if mesg.stderr?
                @append_output(stream:'html',       value:mesg.html)       if mesg.html?
                @append_output(stream:'tex',        value:mesg.tex)        if mesg.tex?
                @append_output(stream:'file',       value:mesg.file)       if mesg.file?
                @append_output(stream:'javascript', value:mesg.javascript) if mesg.javascript?

                if mesg.done
                    @stop_stopwatch()


exports.Cell = Cell

$.fn.extend
    salvus_cell: (opts={}) ->
        return @each () ->
            opts0 = copy(opts)
            opts0.element = this
            $(this).data('cell', new Cell(opts0))

