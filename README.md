# ucGUI-Prop-Font-Combinator

ucGUI Prop型字模库“组合”工具

与 PCtoLCD 程序配合，生成用于 ucGUI 显示用的字模字体文件

### 用法

1. 先用 PCtoLCD 程序分别生成 ASCII 和 NonASCII 的字模文件，

2. 修改此程序配置项中对应的字段，然后在命令行运行 `ruby combinator.rb` 即可

### 注意

* 使用 PCtoLCD 程序时，选项中“输出选项”中仅勾选“输出精简格式”和“输出紧凑格式”，“点阵格式”选择“阴码”，“取模走向”选择“顺向”，“取模方式”选择“逐行式”，“自定义格式”中选择“C51格式”。

* 在生成的字模文件中，手动去除文件开头的索引以及结尾的空行

## License

BSD New License
