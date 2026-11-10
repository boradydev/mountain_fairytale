String routePointPositionsLabel(int count) {
  if (count % 100 >= 11 && count % 100 <= 14) return 'позиций';
  return switch (count % 10) {
    1 => 'позиция',
    2 || 3 || 4 => 'позиции',
    _ => 'позиций',
  };
}
