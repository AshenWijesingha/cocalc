###############################################################################
#
# SageMathCloud: A collaborative web-based interface to Sage, IPython, LaTeX and the Terminal.
#
#    Copyright (C) 2014--2016, SageMath, Inc.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################
# This is a collection of utility classes for printing documents.
# They encapsulate the conversion logic, such that they can be used in editors.
###############################################################################

_               = require('underscore')
async           = require('async')
misc            = require('smc-util/misc')
{salvus_client} = require('./salvus_client')
{redux}         = require('./smc-react')
{project_tasks} = require('./project_tasks')
markdown        = require('./markdown')

# abstract class
class Printer
    constructor : (@editor, @output_file, @opts) ->
        @project_id = @editor.project_id

    # overwrite with the list of supported extensions
    @supported : []

    print : (cb) ->
        console.error('printing: Printer.print method needs to be subclassed')

    show_print_new_tab : (cb) ->
        # if the output file exists and has nonzero size, we open it in a new tab and print it
        project_tasks(@project_id).file_nonzero_size
            path        : @output_file
            cb          : (err) =>
                if err
                    cb?('Generated file for printing does not exist.')
                else
                    redux.getProjectActions(@project_id).download_file
                        path : @output_file
                        print: true
                    cb?()

class PandocPrinter extends Printer
    @supported : ['md', 'html', 'htm', 'rst', 'wiki', 'mediawiki', 'txt'] # , 'csv']

    print: (cb) =>
        @convert_to_pdf (err) =>
            if err
                cb?(err)
            else
                @show_print_new_tab(cb)

    convert_to_pdf: (cb) =>  # cb(err, {stdout:?, stderr:?})
        # this assumes that the outputfile is in the same directory
        infile  = misc.path_split(@editor.filename)
        outfile = misc.path_split(@output_file)

        if @editor.ext in PandocPrinter.supported
            # pandoc --latex-engine=xelatex a.wiki -o a.pdf
            command = 'pandoc'
            args    = ['--latex-engine=xelatex']
            # --wrap=preserve doesn't exist in our old pandoc version
            #if @editor.ext in ['txt', 'csv']
            #    args.push('--wrap=preserve')
            args = args.concat([infile.tail, '-o', outfile.tail])
            bash = false
        else
            cb("'*.#{@editor.ext}' files are currently not supported.")

        output = undefined
        editor = @editor
        async.series([
            (cb) =>
                editor.save(cb)
            (cb) =>
                salvus_client.exec
                    project_id  : editor.project_id
                    command     : command
                    args        : args
                    err_on_exit : true
                    bash        : bash
                    path        : infile.head
                    cb          : (err, o) =>
                        if err
                            cb(err)
                        else
                            output = o
                            cb()
        ], (err) =>
            if err
                cb?(err)
            else
                cb?(undefined, output)
        )

class LatexPrinter extends Printer
    @supported : ['tex']

    print: () ->
        @show_print_new_tab()

class SagewsPrinter extends Printer
    @supported : ['sagews']

    print: (cb, progress) ->
        # cb: callback when done, usual err pattern
        # progress: callback to signal back messages about the conversion progress
        target_ext = misc.filename_extension(@output_file).toLowerCase()
        switch target_ext
            when 'pdf'
                salvus_client.print_to_pdf(cb)
            when 'html'
                @html(cb, progress)

    generate_html: (data) ->
        if not @_html_tmpl?
            # recycle our mathjax config from last.coffee
            {MathJaxConfig} = require('./last')
            MathJaxConfig = _.clone(MathJaxConfig)
            MathJaxConfig.skipStartupTypeset = false
            MathJaxConfig.showProcessingMessages = true
            MathJaxConfig.CommonHTML ?= {}
            MathJaxConfig.CommonHTML.scale = 80
            MathJaxConfig["HTML-CSS"] ?= {}
            MathJaxConfig["HTML-CSS"].scale = 80

            @_html_tmpl = _.template """
                <!doctype html>
                <html lang="en">
                <head>
                    <meta charset="utf-8">

                    <title><%= title %></title>
                    <meta name="description" content="automatically generated from <%= filename %> on SageMathCloud">
                    <meta name="date" content="<%= timestamp %>">

                    <style>
                        html {
                            font-family: sans-serif;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                            margin: 0; padding: 0;
                        }
                        body {
                            max-width: 50rem;
                            counter-reset: line;
                            padding: .5rem;
                        }
                        @media print {
                          body { width: 100%; margin: 1rem; font-size: 12pt; }
                        }

                        div.output {
                            border-left: 1px solid #33a;
                            padding: 0 0 0 .5rem;
                            margin-left: -.5rem;
                        }
                        div.output img { width: 70%; }
                        div.output.stdout, div.output.stderr { font-family: monospace; white-space: pre-wrap; }
                        div.output.stderr { color: red; border-color: #a33; }

                        span.sagews-output-image > img,
                        span.sagews-output-html > img
                        { vertical-align: top; }

                        pre.input { }
                        pre.input > code {
                            display: block;
                            line-height: 1.1rem;
                        }
                        pre.input > code:before {
                            margin-left: -3rem;
                            counter-increment: line;
                            content: counter(line);
                            display: inline-block;
                            border-right: 1px solid #3a3;
                            padding: 0 .5rem 0 0;
                            margin-right: .5rem;
                            color: #888;
                            min-width: 2rem;
                            text-align: right;
                        }
                        div.output:before {
                            margin-left: -3rem;
                            counter-increment: line;
                            content: counter(line);
                            display: inline-block;
                            padding: 0 .5rem 0 0;
                            margin-right: .5rem;
                            color: #888;
                            min-width: 2rem;
                            text-align: right;
                            font-family: monospace;
                        }
                        footer {
                            font-size: 70%;
                            color: #888;
                            text-align: center;
                        }
                    </style>

                    <script type="text/javascript">window.MathJax = #{misc.to_json(MathJaxConfig)};</script>
                    <script type="text/javascript" async
                        src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS_HTML">
                    </script>
                </head>

                <body>
                <div class="header">
                    <h1><%= title %></h1>
                </div>
                <%= content %>
                <hr size=1>
                <div class="footer">
                    <div>generated <%= timestamp %></div>
                </div>

                <!-- https://highlightjs.org/usage/ -->
                <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.8.0/styles/ascetic.min.css">
                <style>
                .hljs {
                    overflow-x : inherit !important;
                    padding    : 0       !important;
                    background : none    !important;
                }
                </style>
                <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.8.0/highlight.min.js"></script>
                <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.8.0/languages/javascript.min.js"></script>
                <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.8.0/languages/python.min.js"></script>
                <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.8.0/languages/r.min.js"></script>
                <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.8.0/languages/coffeescript.min.js"></script>
                <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.8.0/languages/matlab.min.js"></script>
                <script>hljs.initHighlightingOnLoad();</script>
                </body>
                </html>"""
        return @_html_tmpl(data)

    html_process_output_mesg: (mesg, mark) ->
        out = null
        if mesg.stdout?
            out = "<div class='output stdout'>#{mesg.stdout}</div>"
        else if mesg.stderr?
            out = "<div class='output stderr'>#{mesg.stderr}</div>"
        else if mesg.html?
            $html = $("<div>#{mesg.html}</div>")
            @editor.syncdoc.process_html_output($html)
            out = "<div class='output html'>#{$html.html()}</div>"
        else if mesg.md?
            x = markdown.markdown_to_html(mesg.md)
            $out = $("<div>")
            $out.html_noscript(x.s) # also, don't process mathjax!
            @editor.syncdoc.process_html_output($out)
            out = "<div class='output md'>#{$out.html()}</div>"
        else if mesg.file?
            if misc.filename_extension(mesg.file.filename).toLowerCase() == 'sage3d'
                for el in $(mark.replacedWith).find(".salvus-3d-container")
                    $3d = $(el)
                    console.log 'salvus 3d container', $3d
                    scene = $3d.data('salvus-threejs')
                    scene.set_static_renderer()
                    data_url = scene.static_image
                    out = "<div class='output sage3d'><img src='#{data_url}'></div>"
            else
                out = "<div class='output file'>#{mark.widgetNode.innerHTML}</div>"
        else if mesg.code?  # what's that actually?
            code = mesg.code.source
            out = "<pre><code>#{code}</code></pre>"
        else if mesg.javascript?
            code = mesg.javascript.source
            if mesg.javascript.coffeescript
                out = "<pre><code class='lang-coffeescript'>#{code}</code></pre>"
            else
                out = "<pre><code class='lang-javascript'>#{code}</code></pre>"
        else if mesg.done?
            # ignored
        else
            console.warn "ignored mesg", mesg
        return out

    html_embedding_images: (html) ->
        if not html?
            return html
        $html = $(html)
        for img in $html.find('img')
            if img.src.startsWith('data:')
                continue
            c = document.createElement("canvas")
            c.width = img.width
            c.height = img.height
            c.getContext('2d').drawImage(img, 0, 0)
            ext = misc.filename_extension(img.src).toLowerCase()
            ext = ext.split('?')[0]
            if ext == 'svg'
                ext = 'svg+xml'
            else if ext in ['png', 'jpeg']
                _
            else
                console.warn("printing sagews2html image file extension of '#{img.src}' not supported")
                continue
            img.src = c.toDataURL("image/#{ext}")
        console.log "$html", $html
        return $html[0].outerHTML ? ''

    html: (cb, progress) ->
        # the following fits mentally into sagews.SynchronizedWorksheet
        {MARKERS} = require('smc-util/sagews')
        html = [] # list of elements
        cm = @editor.codemirror

        input_lines = []
        input_lines_process = (lang) ->
            # lang is either html, python or md
            lang = if lang? then " lang-#{lang}" else ''
            if input_lines.length > 0
                input_lines = (_.escape(line) for line in input_lines)
                html.push("<pre class='input#{lang}'><code>#{input_lines.join('</code><code>')}</code></pre>")
                input_lines = []

        # process lines in an async loop to avoid blocking on large documents
        line = 0
        lines_total = cm.lineCount()
        async.whilst(
            ->
                progress?("conversion #{misc.round2(line / lines_total)} %")
                line < lines_total
            ,
            (cb) =>
                x = cm.getLine(line)
                marks = cm.findMarks({line:line, ch:0}, {line:line, ch:x.length})
                if not marks? or marks.length == 0
                    input_lines.push(x)
                else
                    input_lines_process()
                    mark = marks[0] # assumption it's always length 1
                    switch x[0]     # first char is the marker
                        when MARKERS.cell
                            x
                        when MARKERS.output
                            # assume, all cells are evaluated and hence mark.rendered contains the html
                            console.log 'output mark', mark
                            for mesg_ser in mark.rendered.split(MARKERS.output)
                                if mesg_ser.length == 0
                                    continue
                                try
                                    mesg = misc.from_json(mesg_ser)
                                catch e
                                    console.warn("invalid output message '#{m}' in line '#{line}'")
                                    continue

                                console.log 'output mesg', mesg
                                output_html = @html_process_output_mesg(mesg, mark)
                                output_html = @html_embedding_images(output_html)
                                if output_html?
                                    html.push(output_html)
                line++
                cb(null, line, x)
            ,
            (err, line, x) ->
                input_lines_process()
                if err
                    msg = "error processing line #{line}: '#{x}'"
                    console.error(msg)
                    cb?(err)
        )

        html_data =
            title     : @editor.filename
            filename  : @editor.filename
            content   : (h for h in html).join('\n')
            timestamp : "#{new Date()}"

        salvus_client.write_text_file_to_project
            project_id : @editor.project_id
            path       : @output_file
            content    : @generate_html(html_data)
            cb         : (err, resp) =>
                console.log("write_text_file_to_project.resp: '#{resp}'")
                cb?(err)

# registering printers
printers = {}
for printer_cls in [PandocPrinter, LatexPrinter, SagewsPrinter]
    for ext in printer_cls.supported
        printers[ext] = printer_cls

###
# Public API
# Printer, usually used like that:
#   p = Printer(@, input_file, output_file, opts)
#   p.print(cb)
#
# can_print(ext) → true or false
###

# returns the printer class for a given file extension
exports.Printer = (editor, output_file, opts) ->
    ext = misc.filename_extension_notilde(editor.filename).toLowerCase()
    return new printers[ext](editor, output_file, opts)

# returns true, if we know how to print it
exports.can_print = (ext) ->
    return _.has(printers, ext)
