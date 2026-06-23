from decimal import Decimal

with open('offsets.txt', 'r') as f:
	lines = f.readlines()

prev = Decimal(lines.pop())
average = prev - int(prev)
if average > 0.1:
  average = 1 - average
print(prev)
print(average)

for line in lines:
  diff = Decimal(line) - prev
  print(f"current {Decimal(line)}, diff {diff}")
  prev = Decimal(line)
  average  = (average + diff)/2

print(f"{(1 - average)* 1000000000000} ps")



