module VFormat
    class Error < RuntimeError
    end

    class DecodeError < Error
    end

    class EncodeError < Error
    end

    class ConvertError < Error
    end


    CRLF = "\r\n"

    # Spec: name = 1*(ALPHA / DIGIT / "-")
    # Note: added '_' to allowed because its produced by Notes - X-LOTUS-CHILD_UID
    #
    NAME_PATTERN = '[-A-Za-z0-9_]+'
    NAME_METHOD_MISSING_REGEXP = /\A([A-Z][-A-Z0-9_]*)(=)?\z/

    # Spec: param-value = ptext / quoted-string
    #
    PVALUE_PATTERN = '(?:"[^"]*"|[^";:,]+)'
    PVALUE_REGEXP  = /"([^"]*)"|([^";:,]+)/

    # Spec: param = name "=" param-value *("," param-value)
    # Note: v2.1 allows a TYPE or ENCODING param-value to appear without the TYPE=
    # or the ENCODING=.
    #
    PARAM_PATTERN = ";#{NAME_PATTERN}(?:=#{PVALUE_PATTERN}(?:,#{PVALUE_PATTERN})*)?"
    PARAM_REGEXP  = /;(#{NAME_PATTERN})(?:=(#{PVALUE_PATTERN}(?:,#{PVALUE_PATTERN})*))?/o

    # V3.0: contentline  =   [group "."]  name *(";" param) ":" value
    # V2.1: contentline  = *( group "." ) name *(";" param) ":" value
    #
    LINE_START_PATTERN = "\\A((?:#{NAME_PATTERN}\\.)+)?(#{NAME_PATTERN})"
    LINE_REGEXP    = /#{LINE_START_PATTERN}((?:#{PARAM_PATTERN})+)?:(.*)\z/o
        LINE_QP_REGEXP = /#{LINE_START_PATTERN}(?:#{PARAM_PATTERN})*;(?:ENCODING=)?QUOTED-PRINTABLE[;:]/oi

        # date = date-fullyear ["-"] date-month ["-"] date-mday
        # date-fullyear = 4 DIGIT
        # date-month    = 2 DIGIT
        # date-mday     = 2 DIGIT
        #
        DATE_PATTERN = "(\\d\\d\\d\\d)-?(\\d\\d)-?(\\d\\d)"
        DATE_REGEXP  = /\A#{DATE_PATTERN}\z/o

        # time = time-hour [":"] time-minute [":"] time-second [time-secfrac] [time-zone]
        # time-hour    = 2 DIGIT
        # time-minute  = 2 DIGIT
        # time-second  = 2 DIGIT
        # time-secfrac = "," 1*DIGIT
        # time-zone    = "Z" / time-numzone
        # time-numzome = sign time-hour [":"] time-minute
        #
        TIME_PATTERN = "(\\d\\d):?(\\d\\d):?(\\d\\d(?:\.\\d+)?)(Z|[-+]\\d\\d:?\\d\\d)?"
        TIME_REGEXP  = /\A#{TIME_PATTERN}\z/o

        # time-date = date "T" time
        #
        DATE_TIME_REGEXP = /\A#{DATE_PATTERN}T#{TIME_PATTERN}\z/o

        # jak mohou vypadat integery
        #
        INT_REGEXP    = /\A[-+]?\d+\z/
        POSINT_REGEXP = /\A\+?\d+\z/

        # nazvy dnu v tydnu
        #
        WEEKDAYS = [ :mo, :tu, :we, :th, :fr, :sa, :su ]

        # setrime pamet:
        #
        BINARY_OR_URL_OR_CID = [:binary, :url, :cid]
        DATE_TIME_OR_DATE    = [:date_time, :date]

end # VFormat


require 'enumerator'
require 'griddler/mailgun/vformat/sasiconv'
require 'griddler/mailgun/vformat/force_encoding'
require 'griddler/mailgun/vformat/attribute'
require 'griddler/mailgun/vformat/value'
require 'griddler/mailgun/vformat/encoder'
require 'griddler/mailgun/vformat/component'


module VFormat
    # inicializace atributu v tride
    #
    @encoders = {}

    class << self # metody tridy

        # [Hash] Zaregistrovane defaultni encodery pro jednotlive nazvy
        # komponent. Format:
        #   {
        #       'VCARD'          => VFormat::Encoder::VCARD30,
        #       ...
        #   }
        #
        attr_accessor :encoders

        # Najde tridu komponenty pro zadany nazev a verzi. Vraci nil, jestlize se
        # ji nalezt nepodarilo. Neni-li zadana verze, znaci to defaultni
        # komponentu pro dany nazev:
        #
        #   VFormat['VCALENDAR'].new do |c|
        #       ...
        #   end
        #
        # To same jako:
        #
        #   VFormat::VCALENDAR20.new do |c|
        #       ...
        #   end
        #
        # Vyhledani podle nazvu a verze:
        #
        #   VFormat['VCALENDAR', '1.0'].new do |c|
        #       ...
        #   end
        #
        # To same jako:
        #
        #   VFormat::VCALENDAR10.new do |c|
        #       ...
        #   end
        #
        #  TODO nevracel nil, ale vyvolat vyjimku
        #
        def [](name, version = nil)
            return nil unless c = @encoders[name]

            if version
                while c.version != version
                    return nil unless c = c.previous_version
                end
            end

            c.components[name]
        end

        # Najde encoder pro zadany nazev komponenty a verzi. Vraci nil, jestlize se
        # ho nalezt nepodarilo. Neni-li zadana verze, znaci to defaultni
        # encoder pro dany nazev.
        #
        def encoder(name, version = nil)
            return nil unless e = @encoders[name]

            if version
                while e.version != version
                    return nil unless e = e.previous_version
                end
            end

            e
        end

        # Rozparsuje retezec do neceho takovehodle:
        #
        # {
        #    :attributes => [
        #        {
        #           :name       => 'VCARD',
        #           :version    => '2.1',
        #           :attributes => [
        #               ['N:...'],
        #               ['ADR:..', '...'], # byl zapsan na vice radcich
        #               ...
        #           ]
        #        },
        #        ...
        #     ]
        # }
        #
        def parse(str)
            root         = { :attributes => [] }
            path         = []  # zanoreni do subcomponent
            current_comp = root

            attr_line    = nil # rozpracovany atribut
            attr_line_qp = false

            add_attr = proc do
                line = attr_line.join('')
                line.delete!(" \t")

                case line
                when /\ABEGIN:(.*)\z/i
                    c = { :name => $1.upcase, :attributes => [] }

                    current_comp[:attributes] << c
                    path << current_comp
                    current_comp = c

                when /\AEND:(.*)\z/i
                    current_comp = path.pop if current_comp[:name] == $1.upcase

                when /\AVERSION:(.*)\z/i
                    current_comp[:version] = $1

                when ''
                    # povolujeme prazdne radky
                    #
                else
                    current_comp[:attributes] << attr_line
                end
            end

            # split +str+ on \r\n or \n to get the lines and unfold continued lines
            # (they start with ' ' or \t)
            #
            str.split(/(?:\r\n|\n)/m).each do |line|
                line.chomp!

                if attr_line
                    # pokracuje rozpracovany atribut na tomto radku?
                    #
                    if attr_line_qp and attr_line.last[-1] == ?=
                        # pokracovani QP textu
                        #
                        attr_line.last.slice!(-1)
                        attr_line << line
                        next
                    end

                    if line =~ /\A[ \t]/
                        # VCARD21, VCAL10 zachovavaji prvni mezeru/tabulator na novem radku,
                        # ostatni ji zahazuji; radky proto nyni nespojime
                        #
                        attr_line << line
                        next
                    end

                    # nepokracuje - pridame rozpracovany atribut
                    #
                    add_attr.call
                end

                # zacatek noveho atributu
                #
                attr_line    = [line]
                attr_line_qp = (line =~ LINE_QP_REGEXP)
            end

            add_attr.call if attr_line
            root
        end


        # Rozparsuje retezec +str+ ve formatu rfc2425 ci pribuznem a vrati v
        # poli vsechny +VFormat::Component+, ktere jsou v nem za sebou
        # zakodovane.
        #
        # Almost nothing is considered a fatal error. Always tries to return
        # something. Muze ale vratit prazdne pole napr. v pripade prazdneho retezce.
        #
        # Chybne radky zapisuje do komponent do pole +invalid_lines+.
        #
        # Na rozparsovanych atributech se neprovadi zadne upravy, jejich hodnoty
        # jsou typu :raw a obsahuji vsechny puvodni parametry jak jsou zapsane
        # ve +str+. Pouze maji nastaven +default_value_type+ na hodnotu
        # odpovidajici nazvu daneho atributu.
        #
        # Format +str+ je automaticky detekovan pomoci nazvu komponenty a jejiho
        # VERSION attributu. Jestlize VERSION atribut chybi, potom se pouzije
        # parametr +version+. Jestlize neni nastaven ani +version+, pouzije se
        # defaultni verze pro parsovanou komponentu.
        #
        # Jestlize neni zadany +encoder+, potom se pokusi pomoci
        # +VFormat::encoder+, nazvu a verze komponenty nalezt a pouzit spravny
        # encoder.
        #
        def decode_raw(str, version = nil, encoder = nil)
            parse(str)[:attributes].delete_if do |atr|
                Array === atr # atribut na nejvyssi urovni nema co delat - preskocime ho
            end.map do |par_comp|
                par_comp[:version] ||= version

                (
                    encoder ||
                    self.encoder(par_comp[:name], par_comp[:version]) ||
                    @encoders[par_comp[:name]] ||
                    Encoder::RFC2425
                ).decode_parsed(par_comp)
            end
        end

        # Rozparsuje retezec +str+ pomoci +decode_raw+ a pote na vsech
        # komponentach spusti +normalize_attributes+.
        #
        # Hodnoty atributu jsou prevedeny do UTF-8 a do spravnych typu. Jsou
        # promazany parametry 'ENCODING', 'CHARSET', a dalsi (viz.
        # +VFormat::Component::normalize_attributes+).
        #
        # Chybne radky jsou zapsany u komponent do pole +invalid_lines+, chybne
        # atributy do pole +invalid_attributes+.
        #
        # Argumenty a navratove hodnoty viz. +VFormat::decode_raw+.
        #
        def decode(str, version = nil, encoder = nil)
            comps = decode_raw(str, version, encoder)
            comps.each {|comp| comp.normalize_attributes}
            comps
        end
    end # VFormat << self
end # VFormat
