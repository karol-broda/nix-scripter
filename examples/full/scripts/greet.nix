{
  description = "Discovered script with a sidecar module";
  args = {
    positional = [
      {
        name = "name";
        optional = true;
        default = "world";
      }
    ];
    options.greeting.default = "hello";
    options.times = {
      short = "n";
      type = "int";
      default = 1;
    };
  };
}
