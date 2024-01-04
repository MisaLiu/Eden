<img align="right" src="docs/eden.png" width="180"/>

# Eden

[![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/MisaLiu/Eden/do.yml?logo=github&label=CI)](https://github.com/MisaLiu/Eden/actions/workflows/do.yml)  [![GitHub all releases](https://img.shields.io/github/downloads/MisaLiu/Eden/total?logo=github&label=Downloads)](https://github.com/MisaLiu/Eden/releases/latest)

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

Please refer to [GitHub Actions workflow file](https://github.com/MisaLiu/Eden/blob/main/.github/workflows/do.yml).

# Thanks

* [pxb1988/dex2jar](https://github.com/pxb1988/dex2jar) - Apache-2.0 License
* [mstrobel/procyon](https://github.com/mstrobel/procyon) - Apache-2.0 License
* [googlecode/android4me](https://code.google.com/archive/p/android4me) - Apache-2.0 License
