import sys

data = open(sys.argv[1], "rb").read()
data += b"\0" * (-len(data) % 4)          # pad to a whole word
for i in range(0, len(data), 4):
    word = int.from_bytes(data[i:i+4], "little")
    print(f"{word:08x}")