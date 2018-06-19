# EEW::Parser

[![Build Status](https://travis-ci.org/mmasaki/eew_parser.svg?branch=master)](https://travis-ci.org/mmasaki/eew_parser)

高度利用者向け緊急地震速報コード電文フォーマットを扱う為のライブラリです。
http://eew.mizar.jp/excodeformat を元に作成しました。
詳しくは http://www.rubydoc.info/gems/eew_parser を参照して下さい。

```ruby
str = <<EOS
37 03 00 110415005029 C11
110415004944
ND20110415005001 NCN001 JD////////////// JN///
189 N430 E1466 070 41 02 RK66204 RT10/// RC/////
9999=
EOS


eew = EEWParser.new(str)
puts "最大予測震度: #{fc.seismic_intensity}"
```

## インストール

```
gem install eew_parser
```

でインストールできます。

## Copyright

Copyright (c) 2018 Masaki Matsushita. See LICENSE.txt for
further details.
