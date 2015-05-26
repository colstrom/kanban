module HashSafety
  refine Hash do
    def keys_contain_symbols?
      self.keys.select { |key| key.is_a? Symbol }.size > 0
    end
  end
end
