class ResizableImageValidator < ActiveModel::EachValidator
  MAX_SIZE = 5.megabytes

  # Only allow resizable image formats
  # SVGs aren't allowed because they can contain XSS
  #
  def validate_each(record, attribute, value)
    return unless value.attached?

    if ActiveStorage.variable_content_types.exclude?(value.content_type)
      record.errors.add(attribute, :image_format_not_supported)
    end

    if value.blob.byte_size > MAX_SIZE
      record.errors.add(attribute, :image_too_large, count: MAX_SIZE / 1.megabyte)
    end
  end
end
