#encoding: utf-8

require_relative "epicenter_code"
require_relative "area_code"

# 緊急地震速報パーサ
# Author:: mmasaki
#
# 高度利用者向け緊急地震速報コード電文フォーマットを扱う為のライブラリです。
# http://eew.mizar.jp/excodeformat を元に作成しました。
#
#   str = <<EOS
#   37 03 00 110415005029 C11
#   110415004944
#   ND20110415005001 NCN001 JD////////////// JN///
#   189 N430 E1466 070 41 02 RK66204 RT10/// RC/////
#   9999=
#   EOS
#
#   eew = EEWParser.new(str)
#   puts "最大予測震度: #{fc.seismic_intensity}"
#
module EEW
  class Parser
    class Error < StandardError; end

    # 引数には緊急地震速報の電文を与えます。
    def initialize(str)
      raise ArgumentError unless str.is_a?(String)
      @fastcast = str.dup
      @fastcast.freeze
      raise Error, "電文の形式が不正です" if @fastcast.bytesize < 135
    end

    attr_reader :fastcast

    # initializeに与えられた電文を返します。
    def to_s
      @fastcast.dup
    end

    # 電文のサイズを返します。
    def size
      @fastcast.bytesize
    end

    # 緊急地震速報の内容をテキストで出力します。
    def print
      return @print.dup if @print

      @print = <<-EOS
緊急地震速報 (第#{number}報)
電文種別: #{type}
発信官署: #{from}
訓練等の識別符: #{drill_type}
電文の発表時刻: #{report_time.strftime("%F %T")}
電文がこの電文を含め何通あるか: #{number_of_telegram}
コードが続くかどうか: #{continue?}
地震発生時刻もしくは地震検知時刻: #{earthquake_time.strftime("%F %T")}
地震識別番号: #{id}
発表状況(訂正等)の指示: #{status}
発表する高度利用者向け緊急地震速報の番号(地震単位での通番): #{number}
震央地名: #{epicenter}
震央の位置: #{position}
震源の深さ(単位 km)(不明・未設定時,キャンセル時:///): #{depth}
マグニチュード(不明・未設定時、キャンセル時:///): #{magnitude}
最大予測震度(不明・未設定時、キャンセル時://): #{seismic_intensity}
震央の確からしさ: #{probability_of_position}
震源の深さの確からしさ: #{probability_of_depth}
マグニチュードの確からしさ: #{probability_of_magnitude}
震央の確からしさ(気象庁の部内システムでの利用): #{probability_of_position_jma}
震源の深さの確からしさ(気象庁の部内システムでの利用): #{probability_of_depth_jma}
震央位置の海陸判定: #{land_or_sea}
警報を含む内容かどうか: #{warning?}
最大予測震度の変化: #{change}
最大予測震度の変化の理由: #{reason_of_change}
      EOS

      if has_ebi?
        @print << "\n地域毎の警報の判別、最大予測震度及び主要動到達予測時刻(EBI):\n"
        ebi.each do |local|
          arrival_time = local[:arrival] ? "すでに到達" : local[:arrival_time]&.strftime("%T")
          @print << "#{local[:area_name]} 最大予測震度: #{local[:intensity]} 予想到達時刻: #{arrival_time} 警報: #{local[:warning]}\n" 
        end
      end

      @print.freeze
      return @print.dup
    end

    Attributes = [
      :type, :from, :drill_type, :report_time, :number_of_telegram, :continue?, :earthquake_time, :id, :status, :final?, :number, :epicenter, :position, :depth,
      :magnitude, :seismic_intensity, :probability_of_position_jma, :probability_of_depth, :probability_of_magnitude, :probability_of_position, :probability_of_depth_jma,
      :land_or_sea, :warning?, :change, :reason_of_change, :ebi
    ].freeze

    # 電文を解析した結果をHashで返します。
    def to_hash
      hash = {}
      Attributes.each do |attribute|
        hash[attribute] = __send__(attribute)
      end
      return hash
    end

    # 正しい電文であるかを返します
    def verify
      Attributes.each do |attribute|
        __send__(attribute)
      end
      return true
    end

    def inspect
      "#<EEWParser:#{id} (第#{number}報) #{epicenter} 震度#{seismic_intensity}>"
    end

    def ==(other)
      fastcast == other.fastcast  
    end

    def <=>(other)
      __id__ <=> other.__id__
    end

    # 電文種別コード
    def type
      case @fastcast[0, 2]
      when "35"
        "最大予測震度のみの高度利用者向け緊急地震速報"
      when "36"
        "マグニチュード、最大予測震度及び主要動到達予測時刻の高度利用者向け緊急地震速報(B-Δ法、テリトリ法)"
      when "37"
        "マグニチュード、最大予測震度及び主要動到達予測時刻の高度利用者向け緊急地震速報(グリッドサーチ法、EPOS自動処理手法)"
      when "39"
        "キャンセル報"
      else
        raise Error, "電文の形式が不正です(電文種別コード)"
      end
    end

    # 発信官署
    def from
      case @fastcast[3, 2]
      when "01"
        "札幌"
      when "02"
        "仙台"
      when "03"
        "東京"
      when "04"
        "大阪"
      when "05"
        "福岡"
      when "06"
        "沖縄"
      else
        raise Error, "電文の形式が不正です(発信官署)"
      end
    end

    # 訓練等の識別符
    def drill_type
      case @fastcast[6, 2]
      when "00"
        "通常"
      when "01"
        "訓練"
      when "10"
        "取り消し"
      when "11"
        "訓練取り消し"
      when "20"
        "参考情報またはテキスト"
      when "30"
        "コード部のみの配信試験"
      else
        raise Error, "電文の形式が不正です(識別符)"
      end
    end

    # 訓練かどうか
    def drill?
      case @fastcast[6, 2]
      when "00", "10", "20"
        return false
      when "01", "11", "30"
        return true
      else
        raise Error, "電文の形式が不正です(識別符)"
      end
    end

    # 電文の発表時刻のTimeオブジェクトを返します。
    def report_time
      Time.local("20" + @fastcast[9, 2], @fastcast[11, 2], @fastcast[13, 2], @fastcast[15, 2], @fastcast[17, 2], @fastcast[19, 2])
    rescue ArgumentError
      raise Error, "電文の形式が不正です (発表時刻: #{@fastcast[9, 12]})"
    end

    # 電文がこの電文を含め何通あるか(Integer)
    def number_of_telegram
      number_of_telegram = @fastcast[23]
      return Integer(number_of_telegram, 10)
    rescue ArgumentError
      raise Error, "電文の形式が不正です"
    end

    # コードが続くかどうか
    def continue?
      case @fastcast[24]
      when "1"
        true
      when "0"
        false
      else
        raise Error, "電文の形式が不正です"
      end
    end

    # 地震発生時刻もしくは地震検知時刻のTimeオブジェクトを返します。
    def earthquake_time
      Time.local("20" + @fastcast[26, 2], @fastcast[28, 2], @fastcast[30, 2], @fastcast[32, 2], @fastcast[34, 2], @fastcast[36, 2])
    rescue ArgumentError
      raise Error, "電文の形式が不正です (地震発生時刻: #{@fastcast[26, 12]})"
    end
    
    # 地震識別番号(String)
    def id
      id = @fastcast[41, 14]
      Integer(id, 10) # verify
      return id
    rescue ArgumentError
      raise Error, "電文の形式が不正です(地震識別番号: #{id})"
    end

    def __id__
      (id * 10) + number
    end

    # 発表状況(訂正等)の指示
    def status
      case @fastcast[59]
      when "0"
        "通常発表"
      when "6"
        "情報内容の訂正"
      when "7"
        "キャンセルを誤って発表した場合の訂正"
      when "8"
        "訂正事項を盛り込んだ最終の高度利用者向け緊急地震速報"
      when "9"
        "最終の高度利用者向け緊急地震速報"
      when "/"
        "未設定"
      else
        raise Error, "電文の形式が不正です"     
      end
    end

    # 発表状況と訓練識別が通常かどうか
    def normal?
      return true if @fastcast[59] == "0" && @fastcast[6, 2] == "00"
      return false
    end

    # 第1報であればtrueを、そうでなければfalseを返します。
    def first? 
      return true if self.number == 1
      return false
    end

    # 最終報であればtrueを、そうでなければfalseを返します。
    def final?
      case @fastcast[59]
      when "9"
        true
      when "0", "6", "7", "8", "/"
        false
      else
        raise Error, "電文の形式が不正です"
      end
    end

    # 発表する高度利用者向け緊急地震速報の番号(地震単位での通番)(Integer)
    def number
      number = @fastcast[60, 2]
      return Integer(number, 10)
    rescue ArgumentError
      raise Error, "電文の形式が不正です(高度利用者向け緊急地震速報の番号: #{number})"
    end

    alias :revision :number

    # 震央の名称
    def epicenter
      code = @fastcast[86, 3]
      code = Integer(code, 10)
      EpicenterCode.fetch(code)
    rescue ArgumentError, KeyError
      raise Error, "電文の形式が不正です(震央地名コード: #{code})"
    end

    # 震央の位置
    def position
      position = @fastcast[90, 10]
      if position == "//// /////"
        "不明又は未設定"
      else
        raise Error, "電文の形式が不正です(震央の位置)" unless position.match(/(?:N|S)\d{3} (?:E|W)\d{4}/)
        position.insert(3, ".").insert(10, ".")
      end
    end

    # 震源の深さ(単位 km)
    def depth
      depth = @fastcast[101, 3]
      if depth == "///"
        return "不明又は未設定"
      else
        return Integer(depth, 10)
      end
    rescue ArgumentError
      raise Error, "電文の形式が不正です(震源の深さ)"
    end

    # マグニチュード
    #   マグニチュードが不明又は未設定である場合は"不明又は未設定"を返します。
    #   そうでなければ、マグニチュードをFloatで返します。
    def magnitude
      magnitude = @fastcast[105, 2]
      if magnitude == "//"
        return "不明又は未設定"
      else
        return Float(magnitude[0] + "." + magnitude[1])
      end
    rescue ArgumentError
      raise Error, "電文の形式が不正です(マグニチュード)"
    end

    SeismicIntensity = {
      "//" => "不明又は未設定",
      "01" => "1",
      "02" => "2",
      "03" => "3",
      "04" => "4",
      "5-" => "5弱",
      "5+" => "5強",
      "6-" => "6弱",
      "6+" => "6強",
      "07" => "7"
    }.freeze

    # 電文フォーマットの震度を文字列に変換
    def to_seismic_intensity(str)
      SeismicIntensity.fetch(str)
    rescue KeyError
      raise Error, "電文の形式が不正です(震度: #{str})"
    end

    # 最大予測震度
    def seismic_intensity
      to_seismic_intensity(@fastcast[108, 2]) 
    end

    OriginProbability = {
      "1" => "P波/S波レベル越え、またはIPF法(1点) または仮定震源要素の場合",
      "2" => "IPF法(2点)",
      "3" => "IPF法(3点/4点)",
      "4" => "IPF法(5点)",
      "5" => "防災科研システム(4点以下、または精度情報なし)[防災科研Hi-netデータ]",
      "6" => "防災科研システム(5点以上)[防災科研Hi-netデータ]",
      "7" => "EPOS(海域[観測網外])",
      "8" => "EPOS(内陸[観測網内])",
      "9" => "予備",
      "/" =>"不明又は未設定"
    }.freeze

    # 震央の確からしさ
    def probability_of_position
      OriginProbability.fetch(@fastcast[113])
    rescue KeyError
      raise Error, "電文の形式が不正です(震央の確からしさ)"
    end

    # 震源の深さの確からしさ
    def probability_of_depth
      OriginProbability.fetch(@fastcast[114])
    rescue KeyError
      raise Error, "電文の形式が不正です(震央の確からしさ)"
    end

    # マグニチュードの確からしさ
    def probability_of_magnitude
      case @fastcast[115]
      when "1"
        "未定義"
      when "2"
        "防災科研システム[防災科研Hi-netデータ]"
      when "3"
        "全点P相"
      when "4"
        "P相/全相混在"
      when "5"
        "全点全相"
      when "6"
        "EPOS"
      when "7"
        "未定義"
      when "8"
        "P波/S波レベル越え または仮定震源要素の場合"
      when "9"
        "予備"
      when "/", "0"
        "不明又は未設定"
      else
        raise Error, "電文の形式が不正です(マグニチュードの確からしさ)"
      end
    end

    # マグニチュード使用観測点（※気象庁の部内システムでの利用）
    def observation_points_of_magnitude
      case @fastcast[116]
      when "1"
        "1点、P波/S波レベル超え、または仮定震源要素"
      when "2"
        "2点"
      when "3"
        "3点"
      when "4"
        "4点"
      when "5"
        "5点以上"
      when "/"
        "不明又は未設定"
      when "6".."9", "0"
        "未定義"
      else
        raise Error, "電文の形式が不正です(マグニチュード使用観測点[気象庁の部内システムでの利用])"
      end
    end

    # 後方互換性のため
    alias probability_of_position_jma observation_points_of_magnitude

    # 震源の深さの確からしさ（※気象庁の部内システムでの利用）
    def probability_of_depth_jma
      case @fastcast[117]
      when "1"
        "P波/S波レベル越え、IPF法(1点)、または仮定震源要素"
      when "2"
        "IPF法(2点)"
      when "3"
        "IPF法(3点/4点)"
      when "4"
        "IPF法(5点以上)"
      when "9"
        "震源とマグニチュードに基づく震度予測手法の精度が最終報相当"
      when "/"
        "不明又は未設定"
      when "5".."8", "0"
        "未定義"
      else
        raise Error, "電文の形式が不正です(震源の深さの確からしさ[気象庁の部内システムでの利用])"
      end
    end

    # 震央位置の海陸判定
    def land_or_sea
      case @fastcast[121]
      when "0"
        "陸域"
      when "1"
        "海域"
      when "/"
        "不明又は未設定"
      when "2".."9"
        "未定義"
      else
        raise Error, "電文の形式が不正です(震央位置の海陸判定)"
      end
    end

    # 警報を含む内容であればtrue、そうでなければfalse
    def warning?
      case @fastcast[122]
      when "0", "/", "2".."9"
        false
      when "1"
        true
      else
        raise Error, "電文の形式が不正です(警報の判別)"
      end
    end

    # 予測手法
    def prediction_method 
      case @fastcast[123]
      when "9"
        "震源とマグニチュードによる震度推定手法において震源要素が推定できず、PLUM 法による震度予測のみが有効である場合"
      when "0".."8"
        "未定義"
      when "/"
        "不明又は未設定"
      else
        raise Error, "電文の形式が不正です(警報の判別)"
      end
    end

    # 最大予測震度の変化
    def change
      case @fastcast[129]
      when "0"
        "ほとんど変化無し"
      when "1"
        "最大予測震度が1.0以上大きくなった"
      when "2"
        "最大予測震度が1.0以上小さくなった"
      when "3".."9"
        "未定義"
      when "/"
        "不明又は未設定"  
      else
        raise Error, "電文の形式が不正です(最大予測震度の変化)"
      end
    end

    # 最大予測震度に変化があったかどうか
    def changed?
      case @fastcast[129]
      when "0", "3".."9", "/"
        return false
      when "1", "2"
        return true
      end
    end

    # 最大予測震度の変化の理由
    def reason_of_change
      case @fastcast[130]
      when "0"
        "変化無し"
      when "1"
        "主としてMが変化したため(1.0以上)"
      when "2"
        "主として震源位置が変化したため(10.0km以上)"
      when "3"
        "M及び震源位置が変化したため"
      when "4"
        "震源の深さが変化したため"
      when "9"
        "PLUM 法による予測により変化したため"
      when "/"
        "不明又は未設定"
      when "5".."8"
        "未定義"
      else
        raise Error, "電文の形式が不正です(最大予測震度の変化の理由)"
      end
    end

    # EBIを含むかどうか
    def has_ebi?
      if @fastcast[135, 3] == "EBI"
        return true
      else
        return false
      end
    end

    # 地域毎の警報の判別、最大予測震度及び主要動到達予測時刻
    #   EBIがあればHashを格納したArrayを、なければ空のArrayを返します。Hashに格納されるkeyとvalueはそれぞれ次のようになっています。
    #   :area_name 地域名称
    #   :intensity 最大予測震度
    #   :arrival_time 予想到達時刻のTimeオブジェクト。既に到達している場合はnil
    #   :warning 警報を含んでいればtrue、含んでいなければfalse、電文にこの項目が設定されていなければnil
    #   :arrival 既に到達していればtrue、そうでなければfalse、電文にこの項目が設定されていなければnil
    def ebi
      return [] unless has_ebi?
      return @ebi.dup if @ebi

      @ebi = []
      i = 139
      while i + 20 < @fastcast.bytesize
        local = {}
        local[:area_code] = @fastcast[i, 3].to_i
        local[:area_name] = AreaCode[local[:area_code]] # 地域名称
        raise Error, "電文の形式が不正でです(地域名称[EBI])" unless local[:area_name]
        if @fastcast[i+7, 2] == "//"
          local[:intensity] = "#{to_seismic_intensity(@fastcast[i+5, 2])}以上" # 最大予測震度
        elsif @fastcast[i+5, 2] == @fastcast[i+7, 2]
          local[:intensity] = "#{to_seismic_intensity(@fastcast[i+5, 2])}"
        else
          local[:intensity] = "#{to_seismic_intensity(@fastcast[i+7, 2])}から#{to_seismic_intensity(@fastcast[i+5, 2])}"
        end
        if @fastcast[i+10, 6] == "//////"
          local[:arrival_time] = nil # 予想到達時刻
        else
          local[:arrival_time] = Time.local("20" + @fastcast[26, 2], @fastcast[28, 2], @fastcast[30, 2], @fastcast[i+10, 2], @fastcast[i+12, 2], @fastcast[i+14, 2])
        end
        case @fastcast[i+17]
        when "0"
          local[:warning] = false # 警報を含むかどうか
        when "1"
          local[:warning] = true
        when "/", "2".."9"
          local[:warning] = nil
        else
          raise Error, "電文の形式が不正でです(警報の判別[EBI])"
        end
        case @fastcast[i+18]
        when "0"
          local[:arrival] = false # 既に到達しているかどうか
        when "1"
          local[:arrival] = true
        when "/", "2".."9"
          local[:arrival] = nil
        else
          raise Error, "電文の形式が不正でです(主要動の到達予測状況[EBI])"
        end
        @ebi << local
        i += 20
      end
      @ebi.freeze
      return @ebi.dup
    end
  end
end

EEWParser = EEW::Parser

if __FILE__ == $PROGRAM_NAME # テスト
  str = <<EOS #テスト用の電文(EBIを含む)
37 03 00 110415233453 C11
110415233416
ND20110415233435 NCN005 JD////////////// JN///
251 N370 E1408 010 66 6+ RK66324 RT01/// RC13///
EBI 251 S6+6- ////// 11 300 S5+5- ////// 11 250 S5+5- ////// 11
310 S0404 ////// 11 311 S0404 ////// 11 252 S0404 ////// 11
301 S0404 ////// 11 221 S0404 ////// 01 340 S0404 ////// 01
341 S0404 ////// 01 321 S0404 233455 00 331 S0404 233457 10
350 S0404 233501 00 360 S0404 233508 00 243 S0403 ////// 01
330 S0403 233454 00 222 S0403 233455 00
9999=
EOS
  
  fc = EEW::Parser.new(str)
  p fc
  p fc.fastcast
  p fc.to_hash
  
  puts <<FC
電文種別コード: #{fc.type}
発信官署: #{fc.from}
訓練等の識別符: #{fc.drill_type}
電文の発表時刻: #{fc.report_time}
電文がこの電文を含め何通あるか: #{fc.number_of_telegram}
コードが続くかどうか: #{fc.continue?}
地震発生時刻もしくは地震検知時刻: #{fc.earthquake_time}
地震識別番号: #{fc.id}
発表状況(訂正等)の指示: #{fc.status}
発表する高度利用者向け緊急地震速報の番号(地震単位での通番): #{fc.number}
震央地名コード: #{fc.epicenter}
震央の位置: #{fc.position}
震源の深さ(単位 km)(不明・未設定時,キャンセル時:///): #{fc.depth}
マグニチュード(不明・未設定時、キャンセル時:///): #{fc.magnitude}
最大予測震度(不明・未設定時、キャンセル時://): #{fc.seismic_intensity}
震央の確からしさ: #{fc.probability_of_position}
震源の深さの確からしさ: #{fc.probability_of_depth}
マグニチュードの確からしさ: #{fc.probability_of_magnitude}
震央の確からしさ(気象庁の部内システムでの利用): #{fc.probability_of_position_jma}
震源の深さの確からしさ(気象庁の部内システムでの利用): #{fc.probability_of_depth_jma}
震央位置の海陸判定: #{fc.land_or_sea}
警報を含む内容かどうか: #{fc.warning?}
最大予測震度の変化: #{fc.change}
最大予測震度の変化の理由: #{fc.reason_of_change}
FC
  fc.ebi.each do |local|
    puts "地域コード: #{local[:area_code]} 地域名: #{local[:area_name]} 最大予測震度: #{local[:intensity]} 予想到達時刻: #{local[:arrival_time]}"
    puts "警報を含むかどうか: #{local[:warning]} 既に到達しているかどうか: #{local[:arrival]}"
  end

  puts fc.print
  p EEW::AreaCode.values.max_by(&:size).size
end
