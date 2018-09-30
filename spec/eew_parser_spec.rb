require_relative "spec_helper"

describe EEW::Parser do
  let(:fastcast) do
    <<-EOS
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
  end

  let(:same_id) do
    EEW::Parser.new(fastcast)
  end

  let(:different_id) do
    _fastcast = fastcast.dup
    _fastcast[61] = "6" # 第6報にセット
    EEW::Parser.new(_fastcast)
  end

  subject do
    EEW::Parser.new(fastcast)
  end

  describe "#==" do
    it "同じ地震IDと第n報目であればtrue" do
      expect(subject).to eq(same_id)
    end

    it "同じ地震IDでも第n報目かが異なればfalse" do
      expect(subject).not_to eq(different_id)
    end
  end

  its(:type) { is_expected.to eq("マグニチュード、最大予測震度及び主要動到達予測時刻の高度利用者向け緊急地震速報(グリッドサーチ法、EPOS自動処理手法)") }

  it { is_expected.not_to be_canceled }

  its(:from) { is_expected.to eq("東京") }

  its(:drill_type) { is_expected.to eq("通常") }

  it { is_expected.not_to be_drill }

  describe "#report_time" do
    let(:report_time) { Time.parse("2011-04-15 23:34:53 +0900") }
    its(:report_time) { is_expected.to eq(report_time) }
  end

  its(:number_of_telegram) { is_expected.to eq(1) }

  it { is_expected.to be_continue }

  describe "#earthquake_time" do
    let(:earthquake_time) { Time.parse("2011-04-15 23:34:16 +0900") }
    its(:earthquake_time) { is_expected.to eq(earthquake_time) }
  end

  its(:id) { is_expected.to eq("20110415233435") }

  its(:status) { is_expected.to eq("通常発表") }

  it { is_expected.to be_normal }

  it { is_expected.not_to be_first }

  it { is_expected.not_to be_final }

  its(:number) { is_expected.to eq(5) }

  its(:epicenter) { is_expected.to eq("福島県浜通り") }

  its(:position) { is_expected.to eq("N37.0 E140.8") }

  its(:depth) { is_expected.to eq(10) }

  its(:magnitude) { is_expected.to eq(6.6) }

  its(:seismic_intensity) { is_expected.to eq("6強") }

  its(:probability_of_position) { is_expected.to eq("防災科研システム(5点以上)[防災科研Hi-netデータ]") }

  its(:probability_of_depth) { is_expected.to eq("防災科研システム(5点以上)[防災科研Hi-netデータ]") }

  its(:probability_of_magnitude) { is_expected.to eq("全点P相") }

  its(:observation_points_of_magnitude) { is_expected.to eq("2点") }

  its(:probability_of_position_jma) { is_expected.to eq("2点") }

  its(:probability_of_depth_jma) { is_expected.to eq("IPF法(5点以上)") }

  its(:land_or_sea) { is_expected.to eq("陸域") }

  its(:warning?) { is_expected.to be true }

  its(:prediction_method) { is_expected.to eq("不明又は未設定") }

  its(:change) { is_expected.to eq("最大予測震度が1.0以上大きくなった") }

  it { is_expected.to be_changed }

  its(:reason_of_change) { is_expected.to eq("M及び震源位置が変化したため") }

  describe "#ebi" do
    let(:ebi) { subject.ebi }
    let(:first) { ebi.first }

    it do
      expect(ebi.size).to eq(17)
      expect(first[:area_code]).to eq(251)
      expect(first[:area_name]).to eq("福島県浜通り")
      expect(first[:arrival]).to be true
      expect(first[:arrival_time]).to be nil
      expect(first[:intensity]).to eq("6弱から6強")
      expect(first[:warning]).to be true
    end
  end

  context "不正な電文" do
    context "nil" do
      it "raises ArgumentError" do
        expect {
          EEW::Parser.new(nil)
        }.to raise_error(ArgumentError)
      end
    end

    context "空文字列" do
      it "raises EEW::Parser::Error" do
        expect {
          EEW::Parser.new("")
        }.to raise_error(EEW::Parser::Error)
      end
    end

    context"途中で欠けている" do
      let(:invalid) do # 途中で欠けた電文
        <<-EOS
37 03 00 110415005029 C11
110415004944
ND20110415005001 NCN001 JD////////////// JN///
189 N430 E1466 070 41 02 RK66204 RT10/// RC////
        EOS
      end

      it "raises EEW::Parser::Error" do
        expect {
          EEW::Parser.new(invalid)
        }.to raise_error(EEW::Parser::Error)
      end
    end
  end

  context "WNIが生成する不正な値を無視(RKnnnn)" do
    let(:invalid) do
      "37 03 00 141215195526 C11\n141215195426\nND20141215195438 NCN903 JD////////////// JN003\n309 N350 E1403 070 38 02 RK77604 RT10/// RC0////\n9999="
    end

    it "can be verified" do
      eew = nil
      expect {
        eew = EEW::Parser.new(invalid)
      }.not_to raise_error
      expect(eew.valid?).to be true
    end
  end

  context "南緯と西経" do
    let(:sw) do
      "37 03 00 141215195526 C11\n141215195426\nND20141215195438 NCN903 JD////////////// JN003\n309 S350 W1403 070 38 02 RK77604 RT10/// RC0////\n9999="
    end

    it "can be verified" do
      eew = nil
      expect {
        eew = EEW::Parser.new(sw)
      }.not_to raise_error
      expect(eew.valid?).to be true
      expect(eew.position).to eq("S35.0 W140.3")
    end
  end

  context "キャンセル報" do
    let(:canceled) do
      "39 04 10 181001002707 C11\n181001002656\nND20181001002656 NCN002 JD////////////// JN///\n/// //// ///// /// // // RK///// RT///// RC/////\n9999="
    end

    it "can be verified" do
      eew = nil
      expect {
        eew = EEW::Parser.new(canceled)
        eew.to_hash
      }.not_to raise_error
      expect(eew.valid?).to be true
      expect(eew.canceled?).to be true
    end
  end
end
