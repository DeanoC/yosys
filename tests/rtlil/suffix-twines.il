autoidx 1
twines
  leaf 1058 "everything"
  suffix 1059 1058 ".a"
  suffix 1060 1058 ".b"
  leaf 1061 "tiny"
end
module $pub@1061  # \tiny
  wire input 1 $pub@1059  # \everything.a
  wire output 2 $pub@1060  # \everything.b
  connect $pub@1060 $pub@1059  # \everything.b \everything.a
end
