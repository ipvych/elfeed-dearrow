New entry hook for [elfeed](https://github.com/skeeto/elfeed) to process youtube
video titles using [DeArrow](https://dearrow.ajay.app/) API.

Additionally a fallback function is provided by default which will run when
DeArrow API does not return any results that will attempt to make title more
boring. Refer to documentation of `elfeed-dearrow-simple-declickbait-entry` on
what it does. You may disable it by setting `elfeed-dearrow-fallback-function`
to `nil`

# Install
```elisp
(package-vc-install '(elfeed-dearrow :url "https://github.com/ipvych/elfeed-dearrow.git"))
(with-eval-after-load 'elfeed
  (add-hook 'elfeed-new-entry-hook #'elfeed-dearrow-update-title))
```

# Support for invidious RSS feeds
You can customize regex in `elfeed-dearrow-link-regexp` to support invidious
instances of your choice.
