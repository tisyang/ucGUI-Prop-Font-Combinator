# coding:utf-8
#
# * * * * * * * * * * * * * *
# 配置项
#
# SJIS 所使用的编码，用于字模文件，输出字体文件，以及字符编码
# 注意，SJIS *应该*不能使用 utf-8 编码
# 应使用兼容 ASCII 的双字节编码，比如 cp936/GB2312/GBK/GB18030，Big5，Shift_JIS 等
SJISEncoding = "cp936"
# ASCII 字模宽度像素值
ASCIIFontWidth = 9
# ASCII 字模宽度字节数
# 如非必要，请勿修改
ASCIIFontWidthBytes = (ASCIIFontWidth / 8.0).ceil
# SJIS 字模宽度像素值
SJISFontWidth = 18
# SIJS 字模宽度字节数
# 如非必要，请勿修改
SJISFontWidthBytes = (SJISFontWidth / 8.0).ceil
# 字模高度像素值
FontHeight = 18
# 输出字体文件名
OutputFontFile = "MyFont.c"


# 字模文件配置
#
# ASCII 的字模文件
# 字模文件为 PCtoLCD 生成，格式请参见测试文件
# 空字符串表示不生成 ASCII
# 注意：如果选择不生成 ASCII，那么程序输出的字体文件中仅输出 SJIS 的字模、字体信息表以及PROP
# 不会输出最终的字体结构定义
ASCIIFontSource = "testASCII.txt"
# ASCII Source 文件中一个字模数据占用的行数
ASCIISourceLineCount = 3
# SJIS 的字模文件
# 字模文件为 PCtoLCD 生成，格式请参见测试文件
# *编码应与 SJISEncoding 一致*
SJISFontSource = "testSJIS.txt"
# SJIS Source 文件中一个字模数据占用的行数
SJISSourceLineCount = 4


# SJIS 限制字符文件
# 仅在生成的字体文件中激活限制字符文件中字符的字模
# 空字符串表示不使用限制字符文件
# *编码应与 SJISEncoding 一致*
#
# 备注：实际使用中，可能受限于 FLASH 容量，无法使用全字符集字库，这时一般有两种选择：
#     1. 仅生成用到的字符的字模。
#     2. 生成较全面的字符集字模，然后仅激活其中用到的字符。
# 方法1占用很少的空间，但灵活性很差，每次需要用到新字符字模时，必须重新生成字体文件。
# 方法2较1多占少量空间，但在需要用到不超过字符集的字符字模时，仅在字符表中激活即可。
# 具体请看生成后的字体文件，即可明白
SJISLimitCharsFile = "limit.txt"


# * * * * * * * * * * * * * *

def encode_byte(byte)
	("%08b" % byte).tr("01", "_X")
end

def decode_font(str, width)
	array = str.gsub(/0x\h\h/).map(&:hex)
	char = str[/(?<=").(?=")/]

	fail "Source file format error: Can not detect char." if char == nil
	fail "Source file format error: Font bytes not equal." if array.size != (width * FontHeight)

	code = char.encode(SJISEncoding).unpack("H*")[0].upcase
	{:char => char, :code => code, :name => "Font_Char_#{code}", :array => array }
end

def dump_font(font, width)
	s = []
	s << "/* char: #{font[:char]}  code:0x#{font[:code]} */"
	s << "GUI_FLASH const unsigned char #{font[:name]}[#{font[:array].count}] = {"
	s += font[:array].map{|x|encode_byte(x)}.each_slice(width).map {|x| x.join(",") + ","}
	s << "};"
	s.join("\n")
end

def parse_source(file, linecount, width)
    content = open(file, "r:#{SJISEncoding}", &:read)
    fonts = content.each_line.each_slice(linecount).map(&:join).map {|x| decode_font(x, width)}
end

def dump_table(fonts, tablename, xsize, width, limit)
    limit_chars = ""
    if limit != ""
        limit_chars = open(limit, "r:#{SJISEncoding}", &:read).strip
    end
    s = []
    s << "GUI_FLASH const GUI_CHARINFO #{tablename}[#{fonts.size}] = {"
    fonts.each do |font|
        if limit_chars.empty? || limit_chars.include?(font[:char])
            s << "\t{#{xsize}, #{xsize}, #{width}, (void GUI_FLASH *)&#{font[:name]}}, /* #{font[:char]} */"
        else
            s << "\t{#{xsize}, #{xsize}, #{width}, (void GUI_FLASH *)0 /*&#{font[:name]}*/}, /* #{font[:char]} */"
        end
    end
    s << "};"
    s.join("\n")
end

def dump_prop(fonts, tablename)
    i = 0
    j = i + 1
    output = []
    count = 0
    while j < fonts.size do
        if fonts[j][:code].hex - fonts[j-1][:code].hex == 1
            j += 1
            next
        end
        count += 1
        prop = []
        prop << "GUI_FLASH const GUI_FONT_PROP Font_Prop_#{count} = {"
        prop << "\t0X#{fonts[i][:code]}, /*start :#{fonts[i][:char]}*/"
        prop << "\t0X#{fonts[j-1][:code]}, /*end   :#{fonts[j-1][:char]}, len=#{j-i}*/"
        prop << "\t&#{tablename}[#{i}],"
        prop << "\t(void GUI_FLASH *)&Font_Prop_#{count+1},"
        prop << "};"
        output << prop
        i = j
        j = i + 1
    end
    if i < fonts.size
        prop = []
        prop << "GUI_FLASH const GUI_FONT_PROP Font_Prop_#{count+1} = {"
        prop << "\t0X#{fonts[i][:code]}, /*start :#{fonts[i][:char]}*/"
        prop << "\t0X#{fonts[j-1][:code]}, /*end   :#{fonts[j-1][:char]}, len=#{j-i}*/"
        prop << "\t&#{tablename}[#{i}],"
        prop << "\t(void GUI_FLASH *)0,"
        prop << "};"
        output << prop
    end

    output.reverse!.map! {|x| x.join("\n")}
    output
end


###########################
def main()
    ascii = nil
    if ASCIIFontSource != ""
        ascii = parse_source(ASCIIFontSource, ASCIISourceLineCount, ASCIIFontWidthBytes)
        ascii.sort_by! {|x| x[:code]}
    end
    sjis = parse_source(SJISFontSource, SJISSourceLineCount, SJISFontWidthBytes)
    sjis.sort_by! {|x| x[:code]}


    open(OutputFontFile, "w:#{SJISEncoding}") do |f|
        f.puts "#include \"GUI.h\"", "\n"
        f.puts "#ifndef GUI_FLASH\n#define GUI_FLASH\n#endif", "\n"

        if ascii != nil
            ascii.each {|font| f.puts dump_font(font, ASCIIFontWidthBytes), "\n"}
            f.puts dump_table(ascii, "ASCII_FontInfoTable", ASCIIFontWidth, ASCIIFontWidthBytes, ""), "\n"
        end

        sjis.each {|font| f.puts dump_font(font, SJISFontWidthBytes), "\n"}
        f.puts dump_table(sjis, "SJIS_FontInfoTable", SJISFontWidth, SJISFontWidthBytes, SJISLimitCharsFile), "\n"

        dump_prop(sjis, "SJIS_FontInfoTable").each {|x| f.puts x, "\n"}

        if ascii != nil
            # ASCII Prop info
            f.puts "GUI_FLASH const GUI_FONT_PROP Font_Prop_ASCII = {"
            f.puts "\t0X#{ascii[0][:code]}, /*start :#{ascii[0][:char]}*/"
            f.puts "\t0X#{ascii[-1][:code]}, /*end   :#{ascii[-1][:char]}, len=#{ascii.size}*/"
            f.puts "\t&ASCII_FontInfoTable[0],"
            f.puts "\t(void GUI_FLASH *)&Font_Prop_1,"
            f.puts "};"

            # Font info
            f.puts "GUI_FLASH const GUI_FONT MyGUI_Font#{FontHeight} = {"
            f.puts "\tGUI_FONTTYPE_PROP_SJIS,"
            f.puts "\t#{FontHeight},"
            f.puts "\t#{FontHeight},"
            f.puts "\t1,"
            f.puts "\t1,"
            f.puts "\t(void GUI_FLASH *)&Font_Prop_ASCII,"
            f.puts "};"
        end
    end

end

if __FILE__ == $0
    main
end
