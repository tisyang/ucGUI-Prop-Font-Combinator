# coding:utf-8
#
# * * * * * * * * * * * * * *
# 配置项
#
# 字符所使用的编码，用于字模文件，输出字体文件，以及字符编码
# 应使用兼容 ASCII 的双字节编码，比如 cp936/GB2312/GBK/GB18030，Big5，Shift_JIS 等，此时生成 Prop-SJIS 类型字体
# 也可以使用 UTF-16BE 编码，此时生成 Prop 类型字体
PropEncoding = "cp936"
# ASCII 字模宽度像素值
ASCIIFontWidth = 9
# ASCII 字模宽度字节数
# 如非必要，请勿修改
ASCIIFontWidthBytes = (ASCIIFontWidth / 8.0).ceil
# 非ASCII 字模宽度像素值
NonASCIIFontWidth = 18
# SIJS 字模宽度字节数
# 如非必要，请勿修改
NonASCIIFontWidthBytes = (NonASCIIFontWidth / 8.0).ceil
# 字模高度像素值
FontHeight = 18
# 输出字体文件名
OutputFontFile = "MyFont.c"
# 输出字体文件编码
# 此编码仅应兼容编译器，且兼容所使用的 Non-ASCII 字符
OutputFontFileEncoding = "cp936"


# 字模文件配置
#
# ASCII 的字模文件
# 字模文件为 PCtoLCD 生成，格式请参见测试文件
# 空字符串表示不生成 ASCII
# 注意：如果选择不生成 ASCII，那么程序输出的字体文件中仅输出 Non-ASCII 的字模、字体信息表以及PROP信息
# 不会输出最终的字体结构定义
ASCIISource = "testASCII.txt"
# ASCII 字模文件中一个字模数据占用的行数
ASCIISourceLineCount = 3
# Non-ASCII 的字模文件
# 字模文件为 PCtoLCD 生成，格式请参见测试文件
NonASCIISource = "testNonASCII.txt"
# Non-ASCII 字模文件编码
NonASCIISourceEncoding = "cp936"
# Non-ASCII 字模文件中一个字模数据占用的行数
NonASCIISourceLineCount = 4


# Non-ASCII 限制字符文件
# 仅在生成的字体文件中激活限制字符文件中字符的字模
# 空字符串表示不使用限制字符文件
#
# 备注：实际使用中，可能受限于 FLASH 容量，无法使用全字符集字库，这时一般有两种选择：
#    1. 仅生成用到的字符的字模。
#    2. 生成较全面的字符集字模，然后仅激活其中用到的字符。
# 方法1占用很少的空间，但灵活性很差，每次需要用到新字符字模时，必须重新生成字体文件。
# 方法2较1多占少量空间，但在需要用到不超过字符集的字符字模时，仅在字符表中激活即可。
# 具体请看生成后的字体文件，即可明白
LimitCharsFile = "limit.txt"
# 编码，默认与 Non-ASCII 字模文件编码相同
LimitCharsFileEncoding = NonASCIISourceEncoding

# * * * * * * * * * * * * * *

def encode_byte(byte)
	("%08b" % byte).tr("01", "_X")
end

def decode_font(str, width)
	array = str.gsub(/0x\h\h/).map(&:hex)
	char = str[/(?<=").(?=")/]

	fail "Source file format error: Can not detect char." if char == nil
	fail "Source file format error: Font bytes not equal." if array.size != (width * FontHeight)

	code = char.encode(PropEncoding).unpack("H*")[0].upcase
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

def parse_source(file, encoding, linecount, width)
	content = open(file, "r:#{encoding}", &:read)

	fonts = content.each_line.each_slice(linecount).map(&:join).map {|x| decode_font(x, width)}
end

def dump_table(fonts, tablename, xsize, width, limit)
	limit_chars = ""
	if limit != ""
		limit_chars = open(limit, "r:#{LimitCharsFileEncoding}", &:read).strip
	end
	s = []
	s << "GUI_FLASH const GUI_CHARINFO #{tablename}[#{fonts.size}] = {"
	fonts.each_with_index do |font, i|
		if limit_chars.empty? || limit_chars.include?(font[:char])
			s << "\t{#{xsize}, #{xsize}, #{width}, (void GUI_FLASH *)&#{font[:name]}}, /* #{i}\t#{font[:char]} */"
		else
			s << "\t{#{xsize}, #{xsize}, #{width}, (void GUI_FLASH *)0 /*&#{font[:name]}*/}, /* #{i}:\t{font[:char]} */"
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
	if ASCIISource != ""
		ascii = parse_source(ASCIISource, "ascii", ASCIISourceLineCount, ASCIIFontWidthBytes)
		ascii.sort_by! {|x| x[:code]}
	end
	nonascii = parse_source(NonASCIISource, NonASCIISourceEncoding, NonASCIISourceLineCount, NonASCIIFontWidthBytes)
	nonascii.sort_by! {|x| x[:code]}


	open(OutputFontFile, "w:#{OutputFontFileEncoding}") do |f|
		f.puts "/* coding:#{OutputFontFileEncoding} */"
		f.puts "#include \"GUI.h\"", "\n"
		f.puts "#ifndef GUI_FLASH\n#define GUI_FLASH\n#endif", "\n"

		if ascii != nil
			ascii.each {|font| f.puts dump_font(font, ASCIIFontWidthBytes), "\n"}
			f.puts dump_table(ascii, "ASCII_FontInfoTable", ASCIIFontWidth, ASCIIFontWidthBytes, ""), "\n"
		end

		nonascii.each {|font| f.puts dump_font(font, NonASCIIFontWidthBytes), "\n"}
		f.puts dump_table(nonascii, "NonASCII_FontInfoTable", NonASCIIFontWidth, NonASCIIFontWidthBytes, LimitCharsFile), "\n"

		dump_prop(nonascii, "NonASCII_FontInfoTable").each {|x| f.puts x, "\n"}

		if ascii != nil
			# ASCII Prop info
			f.puts "GUI_FLASH const GUI_FONT_PROP Font_Prop_ASCII = {"
			f.puts "\t0X#{ascii[0][:code]}, /*start :#{ascii[0][:char]}*/"
			f.puts "\t0X#{ascii[-1][:code]}, /*end	 :#{ascii[-1][:char]}, len=#{ascii.size}*/"
			f.puts "\t&ASCII_FontInfoTable[0],"
			f.puts "\t(void GUI_FLASH *)&Font_Prop_1,"
			f.puts "};", "\n"

			# Font info
			f.puts "GUI_FLASH const GUI_FONT MyGUI_Font#{FontHeight} = {"

			if PropEncoding.downcase == "utf-16be"
				f.puts "\tGUI_FONTTYPE_PROP,"
			else
				f.puts "\tGUI_FONTTYPE_PROP_SJIS,"
			end

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
