<img align="right" src="docs/eden.png" width="180"/>

# Eden

[![do-actions](https://github.com/MisaLiu/Eden/actions/workflows/do.yml/badge.svg?branch=main)](https://github.com/MisaLiu/Eden/actions/workflows/do.yml)

[Eden](https://github.com/MrXiaoM/Eden) is a tool used to analyse large Android application. This fork aim to convert all actions into bash scripts, so users can use this tool for CIs (such as [GitHub Actions](https://docs.github.com/actions)).

# Requirements

* Java 8
* 2GB RAM at least
* 4GB storage at least
* And CLIs below:
  ```
  unzip
  zipinfo
  openssl
  xpath
  ```

# Usage

Please refer to GitHub Actions' config file.

# Thanks

* [pxb1988/dex2jar](https://github.com/pxb1988/dex2jar) - Apache-2.0 License
* [mstrobel/procyon](https://github.com/mstrobel/procyon) - Apache-2.0 License
* [googlecode/android4me](https://code.google.com/archive/p/android4me) - Apache-2.0 License
