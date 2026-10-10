__scripter_args_require() {
  __scripter_args_is_given "$1" || __scripter_args_error "missing required option '$2'"
}
