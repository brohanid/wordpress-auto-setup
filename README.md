# install git (kalau belum ada)
sudo apt update
sudo apt install -y git curl

# clone repo (ambil script dari GitHub)
git clone https://github.com/username/wordpress-auto-setup.git
cd wordpress-auto-setup

# ubah agar bisa dieksekusi
chmod +x setup-wp.sh

# jalankan script + log hasil
sudo bash setup-wp.sh | tee /root/wp-install.log


Alternatif lebih cepat (tanpa clone, langsung curl atau wget dari GitHub RAW):
# langsung download script mentah dari github
curl -sSL https://raw.githubusercontent.com/username/wordpress-auto-setup/main/setup-wp.sh -o setup-wp.sh

chmod +x setup-wp.sh
sudo bash setup-wp.sh | tee /root/wp-install.log
