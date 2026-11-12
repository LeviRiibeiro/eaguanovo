#!/usr/bin/env bash
# Instala o Caixa-e-Água no Linux Mint 22.x (base Ubuntu 24.04).

set -Eeuo pipefail

readonly RELEASE_URL="https://github.com/lifefurb/caixaeagua/releases/download/v1.0/instalacao-caixa-e-agua.tar.gz"
readonly RELEASE_SHA256="63bfef1cbd35b98eda85e7bf30764a1951bdaf75e22d0caa619f8865c0b00489"
readonly APP_HOME="${HOME}/Caixa-e-Agua"
readonly CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}/eaguanovo"
readonly ARCHIVE_PATH="${CACHE_HOME}/instalacao-caixa-e-agua.tar.gz"
readonly BUNDLE_DIR="${CACHE_HOME}/bundle"
readonly BUILD_DIR="${CACHE_HOME}/build"
readonly VRUI_HOME="${HOME}/Vrui-3.1"
RESUME_INSTALL=0

fail() {
  printf '\nErro: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '\n==> %s\n' "$*"
}

cleanup_partial_build() {
  rm -rf -- "${BUILD_DIR:?}/Vrui-3.1-004" "${BUILD_DIR:?}/Kinect-2.8-002" "${BUILD_DIR:?}/SARndbox-1.6"
}

download_bundle() {
  if [[ ! -f "${ARCHIVE_PATH}" ]]; then
    note "Baixando o pacote original (aprox. 150 MB)"
    curl --fail --location --retry 3 --output "${ARCHIVE_PATH}.part" "${RELEASE_URL}"
    mv -- "${ARCHIVE_PATH}.part" "${ARCHIVE_PATH}"
  fi

  local actual_sha
  actual_sha="$(sha256sum "${ARCHIVE_PATH}" | awk '{print $1}')"
  [[ "${actual_sha}" == "${RELEASE_SHA256// /}" ]] || fail "A soma SHA-256 do pacote baixado não confere. Apague ${ARCHIVE_PATH} e tente novamente."
}

unpack_bundle() {
  rm -rf -- "${BUNDLE_DIR:?}"
  mkdir -p -- "${BUNDLE_DIR}"
  tar --extract --gzip --file "${ARCHIVE_PATH}" --directory "${BUNDLE_DIR}" --no-same-owner
  [[ -d "${BUNDLE_DIR}/instalacao-caixa-e-agua" ]] || fail "O pacote de instalação não possui a estrutura esperada."
}

# Vrui 3.1 testa a versão do GCC usando expr. GCC atual devolve somente, por
# exemplo, "13", e o teste legado cai no ramo do GCC 2.x. Este override faz
# o arquivo de dependências ser procurado ao lado do objeto, como GCC 3+ faz.
patch_vrui_dependency_template() {
  local definitions="$1/BuildRoot/SystemDefinitions"
  local marshallers="$1/GL/GLMarshallers.h"
  [[ -f "${definitions}" ]] || fail "Não foi encontrado ${definitions}."
  printf '\n# Compatibilidade com GCC moderno (Mint 22 / Ubuntu 24.04).\nDEPFILETEMPLATE = '\''$(patsubst %%.o,%%.d,$@)'\''\n' >> "${definitions}"

  # GCC recente não traz size_t indiretamente pelos cabeçalhos OpenGL como
  # acontecia quando Vrui 3.1 foi lançado.
  [[ -f "${marshallers}" ]] || fail "Não foi encontrado ${marshallers}."
  if ! grep --quiet '^#include <cstddef>$' "${marshallers}"; then
    sed --in-place '/^#include <GL\/GLMaterial.h>$/a#include <cstddef>' "${marshallers}"
  fi
}

install_dependencies() {
  note "Instalando dependências do Mint 22.3"
  sudo apt update
  sudo apt install --yes \
    build-essential cmake curl pkg-config unzip \
    libasound2-dev libbluetooth-dev libdc1394-dev libgl1-mesa-dev libglu1-mesa-dev \
    libgtk2.0-dev libjpeg-dev libopenal-dev libpng-dev libspeex-dev libtheora-dev \
    libtbb-dev libtiff-dev libudev-dev libusb-1.0-0-dev libv4l-dev \
    libavcodec-dev libavformat-dev libswscale-dev mesa-common-dev scrot zlib1g-dev \
    libopencv-dev qtbase5-dev qtmultimedia5-dev
}

build_vrui() {
  local source_dir="${BUILD_DIR}/Vrui-3.1-004"
  note "Compilando Vrui 3.1"
  tar --extract --gzip --file "${BUNDLE_DIR}/instalacao-caixa-e-agua/Vrui-3.1-004.tar.gz" --directory "${BUILD_DIR}"
  patch_vrui_dependency_template "${source_dir}"
  make --directory "${source_dir}" --jobs "$(nproc)" INSTALLDIR="${VRUI_HOME}"
  make --directory "${source_dir}" INSTALLDIR="${VRUI_HOME}" install
}

build_kinect() {
  local source_dir="${BUILD_DIR}/Kinect-2.8-002"
  note "Compilando Kinect 2.8"
  tar --extract --gzip --file "${BUNDLE_DIR}/instalacao-caixa-e-agua/Kinect-2.8-002.tar.gz" --directory "${BUILD_DIR}"
  make --directory "${source_dir}" --jobs "$(nproc)"
  make --directory "${source_dir}" install
  make --directory "${source_dir}" installudevrule
}

build_sarndbox() {
  local source_dir="${BUILD_DIR}/SARndbox-1.6"
  local runtime_dir="${APP_HOME}/sarndbox-runtime"
  note "Compilando SARndbox 1.6"
  tar --extract --gzip --file "${BUNDLE_DIR}/instalacao-caixa-e-agua/SARndbox-1.6.tar.gz" --directory "${BUILD_DIR}"
  make --directory "${source_dir}" --jobs "$(nproc)" INSTALLDIR="${runtime_dir}"
  make --directory "${source_dir}" INSTALLDIR="${runtime_dir}" install
  ln --symbolic --force "../sarndbox-runtime/bin/SARndbox" "${APP_HOME}/auxs/SARndbox"
}

patch_opencv4_source() {
  local source_root="$1"
  find "${source_root}" -type f \( -name '*.cpp' -o -name '*.h' \) -print0 | xargs -0 sed --in-place \
    -e 's/CV_BGR2GRAY/cv::COLOR_BGR2GRAY/g' \
    -e 's/CV_GRAY2BGR/cv::COLOR_GRAY2BGR/g' \
    -e 's/CV_HOUGH_GRADIENT/cv::HOUGH_GRADIENT/g' \
    -e 's/CV_RETR_TREE/cv::RETR_TREE/g' \
    -e 's/CV_CHAIN_APPROX_SIMPLE/cv::CHAIN_APPROX_SIMPLE/g' \
    -e 's/CV_LOAD_IMAGE_UNCHANGED/cv::IMREAD_UNCHANGED/g' \
    -e 's/CV_WINDOW_NORMAL/cv::WINDOW_NORMAL/g' \
    -e 's/CV_WND_PROP_FULLSCREEN/cv::WND_PROP_FULLSCREEN/g' \
    -e 's/CV_WINDOW_FULLSCREEN/cv::WINDOW_FULLSCREEN/g' \
    -e 's/CV_THRESH_BINARY/cv::THRESH_BINARY/g' \
    -e 's/cvSetWindowProperty/setWindowProperty/g'
}

build_caixa_helpers() {
  local source_root="${APP_HOME}/sources"
  local helper
  note "Compilando as ferramentas auxiliares com OpenCV 4"
  patch_opencv4_source "${source_root}"

  for helper in Calibrar_Mundo Compara_Imagens Show_Img_Fullscreen Valida_Marcadores; do
    cmake --fresh -S "${source_root}/${helper}" -B "${source_root}/${helper}/build"
    cmake --build "${source_root}/${helper}/build" --parallel "$(nproc)"
  done

  install -m 0755 "${source_root}/Calibrar_Mundo/build/CalibrarMundo" "${APP_HOME}/auxs/CalibrarMundo"
  install -m 0755 "${source_root}/Compara_Imagens/build/ComparaImagens" "${APP_HOME}/auxs/ComparaImagens"
  install -m 0755 "${source_root}/Show_Img_Fullscreen/build/showFullScreen" "${APP_HOME}/auxs/showFullScreen"
  install -m 0755 "${source_root}/Valida_Marcadores/build/ValidarMarcadores" "${APP_HOME}/auxs/ValidarMarcadores"
}

install_application_files() {
  if [[ -e "${APP_HOME}" ]]; then
    [[ "${RESUME_INSTALL}" -eq 1 ]] || fail "${APP_HOME} já existe. Para preservá-la, o instalador não a sobrescreve. Se ela foi criada por uma execução anterior deste instalador, execute novamente com --resume."
    [[ -d "${APP_HOME}/auxs" && -d "${APP_HOME}/sources" ]] || fail "${APP_HOME} não tem a estrutura esperada para retomar a instalação. Renomeie ou faça backup dessa pasta antes de executar novamente."
    note "Retomando com os arquivos da aplicação já extraídos"
    return
  fi
  note "Instalando arquivos do Caixa-e-Água"
  tar --extract --gzip --file "${BUNDLE_DIR}/instalacao-caixa-e-agua/Caixa-e-Agua.tar.gz" --directory "${HOME}" --no-same-owner
  [[ -d "${APP_HOME}/auxs" ]] || fail "A aplicação não foi extraída corretamente."
}

create_launcher() {
  local launcher="${HOME}/.local/bin/Caixa-e-Agua"
  local desktop_entry="${HOME}/.local/share/applications/Caixa-e-Agua.desktop"
  local desktop_dir
  [[ -f "${APP_HOME}/bin/Caixa_v1" ]] || fail "Não foi encontrado ${APP_HOME}/bin/Caixa_v1."
  chmod 0755 "${APP_HOME}/bin/Caixa_v1"
  mkdir -p -- "${HOME}/.local/bin"
  printf '#!/usr/bin/env bash\ncd "%s/bin"\nexec ./Caixa_v1\n' "${APP_HOME}" > "${launcher}"
  chmod 0755 "${launcher}"

  mkdir -p -- "${HOME}/.local/share/applications"
  printf '[Desktop Entry]\nVersion=1.0\nType=Application\nName=Caixa-e-Água\nComment=Caixa de Areia Interativa\nExec=%s\nIcon=%s\nTerminal=false\nCategories=Education;Science;\n' \
    "${launcher}" "${APP_HOME}/resources/logos/icone.jpg" > "${desktop_entry}"
  chmod 0644 "${desktop_entry}"

  desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s/Desktop' "${HOME}")"
  mkdir -p -- "${desktop_dir}"
  if [[ ! -e "${desktop_dir}/Caixa-e-Agua.desktop" ]]; then
    ln --symbolic "${desktop_entry}" "${desktop_dir}/Caixa-e-Agua.desktop"
  fi
}

main() {
  if [[ "${1:-}" == "--resume" ]]; then
    RESUME_INSTALL=1
  elif [[ "$#" -ne 0 ]]; then
    fail "Opção desconhecida: $1. Use sem opções ou --resume."
  fi

  [[ "$(uname -s)" == "Linux" ]] || fail "Este instalador é destinado ao Linux."
  command -v sudo >/dev/null || fail "sudo não está disponível."
  mkdir -p -- "${CACHE_HOME}" "${BUILD_DIR}"

  install_dependencies
  download_bundle
  unpack_bundle
  cleanup_partial_build
  install_application_files
  build_vrui
  build_kinect
  build_sarndbox
  build_caixa_helpers
  create_launcher

  note "Instalação concluída"
  printf 'Abra pelo menu ou execute: %s\n' "${HOME}/.local/bin/Caixa-e-Agua"
  printf 'Se o Kinect já estava conectado, desconecte-o e conecte-o novamente para aplicar a regra udev.\n'
}

main "$@"
