autoidx 1
twines
  leaf 1058 "home"
  suffix 1059 1058 ".repo"
  suffix 1060 1059 ".chain"
  suffix 1061 1060 ".in"
  suffix 1062 1060 ".out"
end
module \chain
  wire input 1 $pub@1061  # \home.repo.chain.in
  wire output 2 $pub@1062  # \home.repo.chain.out
  connect $pub@1062 $pub@1061  # \home.repo.chain.out \home.repo.chain.in
end
