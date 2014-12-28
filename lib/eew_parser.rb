#encoding: utf-8

require_relative "epicenter_code"
require_relative "area_code"

# 緊急地震速報パーサ
# Author:: Glass_saga
# License:: NYSL Version 0.9982
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
      raise Error, "電文の形式が不正です" if @fastcast.size < 135
    end

    attr_reader :fastcast

    # initializeに与えられた電文を返します。
    def to_s
      @fastcast
    end

    def print
      str = <<-EOS
電文種別: #{self.type}
発信官署: #{self.from}
訓練等の識別符: #{self.drill_type}
電文の発表時刻: #{self.report_time}
電文がこの電文を含め何通あるか: #{self.number_of_telegram}
コードが続くかどうか: #{self.continue?}
地震発生時刻もしくは地震検知時刻: #{self.earthquake_time}
地震識別番号: #{self.id}
発表状況(訂正等)の指示: #{self.status}
発表する高度利用者向け緊急地震速報の番号(地震単位での通番): #{self.number}
震央地名: #{self.epicenter}
震央の位置: #{self.position}
震源の深さ(単位 km)(不明・未設定時,キャンセル時:///): #{self.depth}
マグニチュード(不明・未設定時、キャンセル時:///): #{self.magnitude}
最大予測震度(不明・未設定時、キャンセル時://): #{self.seismic_intensity}
震央の確からしさ: #{self.probability_of_position}
震源の深さの確からしさ: #{self.probability_of_depth}
マグニチュードの確からしさ: #{self.probability_of_magnitude}
震央の確からしさ(気象庁の部内システムでの利用): #{self.probability_of_position_jma}
震源の深さの確からしさ(気象庁の部内システムでの利用): #{self.probability_of_depth_jma}
震央位置の海陸判定: #{self.land_or_sea}
警報を含む内容かどうか: #{self.warning?}
最大予測震度の変化: #{self.change}
最大予測震度の変化の理由: #{self.reason_of_change}
      EOS

      unless self.ebi.empty?
        str << "\n地域毎の警報の判別、最大予測震度及び主要動到達予測時刻(EBI):"
        self.ebi.each do |local|
          str << "地域名: #{local[:area_name]} 最大予測震度: #{local[:intensity]} 予想到達時刻: #{local[:arrival_time]} 警報を含むかどうか: #{local[:warning]} 既に到達しているかどうか: #{local[:arrival]}\n"
        end
      end

      return str
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

    def inspect
      "#<EEWParser:#{id}>"
    end

    def ==(other)
      fastcast == other.fastcast  
    end

    def <=>(other)
      Integer(id) <=> Integer(id)
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

    # 電文の発表時刻のTimeオブジェクトを返します。
    def report_time
      Time.local("20" + @fastcast[9, 2], @fastcast[11, 2], @fastcast[13, 2], @fastcast[15, 2], @fastcast[17, 2], @fastcast[19, 2])
    end

    # 電文がこの電文を含め何通あるか(Integer)
    def number_of_telegram
      number_of_telegram = @fastcast[23]
      raise Error, "電文の形式が不正です" if number_of_telegram =~ /[^\d]/
      number_of_telegram.to_i
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
    end
    
    # 地震識別番号(String)
    def id
      id = @fastcast[41, 14]
      raise Error, "電文の形式が不正です(地震識別番号)" if id =~ /[^\d]/
      id
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
      raise Error, "電文の形式が不正です(高度利用者向け緊急地震速報の番号)" if number =~ /[^\d]/
      number.to_i
    end

    alias :revision :number

    # 震央の名称
    def epicenter
      key = @fastcast[86, 3]
      raise Error, "電文の形式が不正です(震央の名称)" if key =~ /[^\d]/
      EpicenterCode[key.to_i]
    end

    # 震央の位置
    def position
      position = @fastcast[90, 10]
      if position == "//// /////"
        "不明又は未設定"
      else
        raise Error, "電文の形式が不正です(震央の位置)" if position =~ /[^\d|\s|N|E]/
        position.insert(3, ".").insert(10, ".")
      end
    end

    # 震源の深さ(単位 km)
    def depth
      depth = @fastcast[101, 3]
      if depth == "///"
        "不明又は未設定"
      else
        raise Error, "電文の形式が不正です(震源の深さ)" if depth =~ /[^\d]/
        depth.to_i
      end
    end

    # マグニチュード
    #   マグニチュードが不明又は未設定である場合は"不明又は未設定"を返します。
    #   そうでなければ、マグニチュードをFloatで返します。
    def magnitude
      magnitude = @fastcast[105, 2]
      if magnitude == "//"
        "不明又は未設定"
      else
        raise Error, "電文の形式が不正です(マグニチュード)" if magnitude =~ /[^\d]/
        (magnitude[0] + "." + magnitude[1]).to_f
      end
    end

    # 電文フォーマットの震度を文字列に変換
    def to_seismic_intensity(str)
      case str
      when "//"
        "不明又は未設定"
      when "01"
        "1"
      when "02"
        "2"
      when "03"
        "3"
      when "04"
        "4"
      when "5-"
        "5弱"
      when "5+"
        "5強"
      when "6-"
        "6弱"
      when "6+"
        "6強"
      when "07"
        "7"
      else
        raise Error, "電文の形式が不正です(震度)"
      end
    end

    # 最大予測震度
    def seismic_intensity
      to_seismic_intensity(@fastcast[108, 2]) 
    rescue Error
      raise Error, "電文の形式が不正です(最大予測震度)" 
    end

    # 震央の確からしさ
    def probability_of_position
      case @fastcast[113]
      when "1"
        "P波/S波レベル越え、またはテリトリー法(1点)[気象庁データ]"
      when "2"
        "テリトリー法(2点)[気象庁データ]"
      when "3"
        "グリッドサーチ法(3点/4点)[気象庁データ]"
      when "4"
        "グリッドサーチ法(5点)[気象庁データ]"
      when "5"
        "防災科研システム(4点以下、または精度情報なし)[防災科学技術研究所データ]"
      when "6"
        "防災科研システム(5点以上)[防災科学技術研究所データ]"
      when "7"
        "EPOS(海域[観測網外])[気象庁データ]"
      when "8"
        "EPOS(内陸[観測網内])[気象庁データ]"
      when "9"
        "予備"
      when "/"
        "不明又は未設定"
      else
        raise Error, "電文の形式が不正です(震央の確からしさ)"
      end    
    end

    # 震源の深さの確からしさ
    def probability_of_depth
      case @fastcast[114]
      when "1"
        "P波/S波レベル越え、またはテリトリー法(1点)[気象庁データ]"
      when "2"
        "テリトリー法(2点)[気象庁データ]"
      when "3"
        "グリッドサーチ法(3点/4点)[気象庁データ]"
      when "4"
        "グリッドサーチ法(5点)[気象庁データ]"
      when "5"
        "防災科研システム(4点以下、または精度情報なし)[防災科学技術研究所データ]"
      when "6"
        "防災科研システム(5点以上)[防災科学技術研究所データ]"
      when "7"
        "EPOS(海域[観測網外])[気象庁データ]"
      when "8"
        "EPOS(内陸[観測網内])[気象庁データ]"
      when "9"
        "予備"
      when "/", "0"
        "不明又は未設定"
      else
        raise Error, "電文の形式が不正です(震源の深さの確からしさ)"
      end 
    end

    # マグニチュードの確からしさ
    def probability_of_magnitude
      case @fastcast[115]
      when "1"
        "未定義"
      when "2"
        "防災科研システム[防災科学技術研究所データ]"
      when "3"
        "全点P相(最大5点)[気象庁データ]"
      when "4"
        "P相/全相混在[気象庁データ]"
      when "5"
        "全点全相(最大5点)[気象庁データ]"
      when "6"
        "EPOS[気象庁データ]"
      when "7"
        "未定義"
      when "8"
        "P波/S波レベル越え[気象庁データ]"
      when "9"
        "予備"
      when "/", "0"
        "不明又は未設定"
      else
        raise Error, "電文の形式が不正です(マグニチュードの確からしさ)"
      end
    end

    # 震央の確からしさ（※気象庁の部内システムでの利用）
    def probability_of_position_jma
      case @fastcast[116]
      when "1"
        "P波/S波レベル越え又はテリトリー法(1点)[気象庁データ]"
      when "2"
        "テリトリー法(2点)[気象庁データ]"
      when "3"
        "グリッドサーチ法(3点/4点)[気象庁データ]"
      when "4"
        "グリッドサーチ法(5点)[気象庁データ]"
      when "/"
        "不明又は未設定"
      when "5".."9", "0"
        "未定義"
      else
        raise Error, "電文の形式が不正です(震央の確からしさ[気象庁の部内システムでの利用])"
      end
    end

    # 震源の深さの確からしさ（※気象庁の部内システムでの利用）
    def probability_of_depth_jma
      case @fastcast[117]
      when "1"
        "P波/S波レベル越え又はテリトリー法(1点)[気象庁データ]"
      when "2"
        "テリトリー法(2点)[気象庁データ]"
      when "3"
        "グリッドサーチ法(3点/4点)[気象庁データ]"
      when "4"
        "グリッドサーチ法(5点)[気象庁データ]"
      when "/"
        "不明又は未設定"
      when "5".."9", "0"
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
      when "/"
        "不明又は未設定"
      when "5".."9"
        "未定義"
      else
        raise Error, "電文の形式が不正です(最大予測震度の変化の理由)"
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
      data = []
      return data unless @fastcast[135, 3] == "EBI"
      i = 139
      while i + 20 < @fastcast.size
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
        data << local
        i += 20
      end
      data
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
end
