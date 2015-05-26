module HashSafety
  refine Hash do
    def keys_contain_symbols?
      self.keys.select { |key| key.is_a? Symbol }.size > 0
    end

    def with_string_keys
      self.each_with_object({}) do |(key,value),hash|
        hash[key.to_s] = value
        hash
      end
    end
  end
end
