return require('ldoc.html._reset_css') .. [[

body {
    margin-left: 1em;
    margin-right: 1em;
    font-family: arial, helvetica, geneva, sans-serif;
    background-color: #ffffff; margin: 0px;
}

code, tt { font-family: monospace; font-size: 1.1em; }
span.parameter { font-family:monospace; }
span.parameter:after { content:":"; }
span.types:before { content:"("; }
span.types:after { content:")"; }
.type { font-weight: bold; font-style:italic }

body, p, td, th { font-size: .95em; line-height: 1.2em;}

p, ul { margin: 10px 0 0 0px;}

strong { font-weight: bold;}

em { font-style: italic;}

h1 {
    font-size: 1.5em;
    margin: 0 0 20px 0;
}
h2, h3, h4 { margin: 15px 0 10px 0; }
h2 { font-size: 1.25em; }
h3 { font-size: 1.15em; }
h4 { font-size: 1.06em; }

a:link { font-weight: bold; color: #004080; text-decoration: none; }
a:visited { font-weight: bold; color: #006699; text-decoration: none; }
a:link:hover { text-decoration: underline; }

hr {
    color:#cccccc;
    background: #00007f;
    height: 1px;
}

blockquote { margin-left: 3em; }

ul { list-style-type: disc; }

p.name {
    font-family: "Andale Mono", monospace;
    padding-top: 1em;
}

pre {
    background-color: rgb(245, 245, 245);
    border: 1px solid #C0C0C0; /* silver */
    padding: 10px;
    margin: 10px 0 10px 0;
    overflow: auto;
    font-family: "Andale Mono", monospace;
}

pre.example {
    font-size: .85em;
}

table.index { border: 1px #00007f; }
table.index td { text-align: left; vertical-align: top; }

#container {
    margin-left: 1em;
    margin-right: 1em;
    background-color: #ffffff;
}

#product {
    text-align: center;
    border-bottom: 1px solid #cccccc;
    background-color: #ffffff;
}

#product big {
    font-size: 2em;
}

#main {
    background-color:#FFFFFF; // #f0f0f0;
    border-left: 1px solid #cccccc;
}

#navigation {
    position: fixed;
    top: 0;
    left: 0;
    float: left;
    width: 14em;
    vertical-align: top;
    background-color:#FFFFFF; // #f0f0f0;
    border-right: 2px solid #cccccc;
    overflow: visible;
    overflow-y: scroll;
    height: 100%;
    padding-left: 1em;
}

#navigation h2 {
    background-color:#FFFFFF;//:#e7e7e7;
    font-size:1.1em;
    color:#000000;
    text-align: left;
    padding:0.2em;
    border-bottom:1px solid #dddddd;
}

#navigation ul
{
    font-size:1em;
    list-style-type: none;
    margin: 1px 1px 10px 1px;
}

#navigation li {
    text-indent: -1em;
    display: block;
    margin: 3px 0px 0px 22px;
}

#navigation li li a {
    margin: 0px 3px 0px -1em;
}

#content {
    margin-left: 20em;
    padding: 1em;
    padding-left: 2em;
    border-left: 2px solid #cccccc;
   // border-right: 2px solid #cccccc;
    background-color: #ffffff;
}

#about {
    clear: both;
    padding-left: 1em;
    margin-left: 14em; // avoid the damn sidebar!
    border-top: 2px solid #cccccc;
    border-left: 2px solid #cccccc;
    background-color: #ffffff;
}

@media print {
    body {
        font: 12pt "Times New Roman", "TimeNR", Times, serif;
    }
    a { font-weight: bold; color: #004080; text-decoration: underline; }

    #main {
        background-color: #ffffff;
        border-left: 0px;
    }

    #container {
        margin-left: 2%;
        margin-right: 2%;
        background-color: #ffffff;
    }

    #content {
        padding: 1em;
        background-color: #ffffff;
    }

    #navigation {
        display: none;
    }
    pre.example {
        font-family: "Andale Mono", monospace;
        font-size: 10pt;
        page-break-inside: avoid;
    }
}

table.module_list {
    border-width: 1px;
    border-style: solid;
    border-color: #cccccc;
    border-collapse: collapse;
}
table.module_list td {
    border-width: 1px;
    padding: 3px;
    border-style: solid;
    border-color: #cccccc;
}
table.module_list td.name { background-color: #f0f0f0; ; min-width: 200px; }
table.module_list td.summary { width: 100%; }

table.function_list {
    border-width: 1px;
    border-style: solid;
    border-color: #cccccc;
    border-collapse: collapse;
}
table.function_list td {
    border-width: 1px;
    padding: 3px;
    border-style: solid;
    border-color: #cccccc;
}
table.function_list td.name { background-color: #f6f6ff; ; min-width: 200px; }
table.function_list td.summary { width: 100%; }

dl.table dt, dl.function dt {border-top: 1px solid #ccc; padding-top: 1em;}
dl.table dd, dl.function dd {padding-bottom: 1em; margin: 10px 0 0 20px;}
dl.table h3, dl.function h3 {font-size: .95em;}

ul.nowrap {
    overflow:auto;
    whitespace:nowrap;
}

/* stop sublists from having initial vertical space */
ul ul { margin-top: 0px; }
ol ul { margin-top: 0px; }
ol ol { margin-top: 0px; }
ul ol { margin-top: 0px; }

/* make the target distinct; helps when we're navigating to a function */
a:target + * {
  background-color: #FF9;
}

]]
.. require('ldoc.html._code_css')
