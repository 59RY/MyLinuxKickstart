#!/bin/bash

# AWS におけるEBSのコストを削減しながらスナップショットを作成するため、
# 512KiB のブロック単位でディスクを書き込みます。

# ユーザーに入力元・出力先・コピーするブロック数を問い合わせる
read -p "入力元のデバイス名 または ディスクイメージ(raw)を入力してください（例: /dev/nvme1n1）: " input_device
read -p "出力先のデバイス名を入力してください（例: /dev/nvme2n1）: " output_device
read -p "コピーするブロック数を入力してください（単位: 512KiB）: " NUM_BLOCKS

echo -e "\n入力元: ${input_device}"
echo "出力先: ${output_device}"
echo "コピーするブロック数: ${NUM_BLOCKS}"
read -p "実行する場合は何かキーを、実行中止する場合は Ctrl + C を押してください..."

# 一時ファイルを作成
BLOCK_TEMP=$(mktemp)
ZERO_TEMP=$(mktemp)

# 512KiB のゼロブロックを生成
dd if=/dev/zero of="$ZERO_TEMP" bs=512K count=1 status=none

# 書き込みブロック数のカウンタ初期化
written_blocks=0

# 指定されたブロック数だけループ
for ((i=0; i<NUM_BLOCKS; i++)); do
	echo "ブロック $i を処理中..."
	
	# 入力デバイスから1ブロック(512KiB)を読み出し
	dd if="$input_device" of="$BLOCK_TEMP" bs=512K count=1 skip=$i status=none

	# ブロックが全ゼロならスキップ、そうでなければ出力デバイスに書き込み
	if cmp -s "$BLOCK_TEMP" "$ZERO_TEMP"; then
		echo "ブロック $i は全ゼロなのでスキップします。"
	else
		echo "ブロック $i を ${output_device} に書き込みます。"
		dd if="$BLOCK_TEMP" of="$output_device" bs=512K count=1 seek=$i conv=notrunc status=none
		written_blocks=$((written_blocks+1))
	fi
done

# 一時ファイルを削除
rm "$BLOCK_TEMP" "$ZERO_TEMP"

# 書き込み合計を計算（1ブロック = 512KiB = 0.5MiB）
total_mib=$(awk "BEGIN {printf \"%.1f\", $written_blocks/2}")

echo "ディスクコピーが完了しました。"
echo "合計で書き込んだブロック数: ${written_blocks} ブロック"
echo "合計で書き込んだ容量: ${total_mib} MiB"
