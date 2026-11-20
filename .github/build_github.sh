# 纯净版：把 archive 中的应用搬到 Payload，移除内置 SideStore 框架后打包
mv "$archive_path.xcarchive/Products/Applications" Payload

# 纯净版不内置 SideStore，确保框架不会进入 IPA
rm -rf Payload/LiveContainer.app/Frameworks/SideStoreSupport.framework

zip -r "$scheme.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
