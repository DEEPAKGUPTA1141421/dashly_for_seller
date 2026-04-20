# dashly_for_seller

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


setp 1 http://localhost:8081/api/v1/seller/product/create
{
    "success": true,
    "message": "Product Created",
    "data": {
        "productId": "94bab102-45c6-4db0-99f4-4fab766d2ebd"
    },
    "statusCode": 200
}

step 2 http://localhost:8081/api/v1/seller/product/create-product-attribute
{
    "success": true,
    "message": "Saved In The Db",
    "data": [
        {
            "id": "8d00864c-425f-4065-8106-34e1f7236024",
            "categoryAttributeId": "033db04c-6fcc-4dc6-91c3-56171200a958",
            "name": "age",
            "value": "men",
            "variants": []
        },
        {
            "id": "3be38ea6-75b0-4b40-b88a-30270df8a953",
            "categoryAttributeId": "c31cc120-c924-45d6-bcf3-db0eba9813db",
            "name": "Pattern",
            "value": "Solid",
            "variants": []
        },
        {
            "id": "6b01f022-e14e-43f8-97ce-da9c7f09046e",
            "categoryAttributeId": "33e1e2c4-6d6b-45d4-8730-58c0830c479c",
            "name": "Color",
            "value": "Red",
            "variants": []
        },
        {
            "id": "8166a0a5-b606-44dc-94f9-345334281b94",
            "categoryAttributeId": "766e0423-29aa-4466-aa64-1f82e8de91a6",
            "name": "Material",
            "value": "cotton",
            "variants": []
        },
        {
            "id": "9b915199-99eb-47db-a9b7-35c8806f2202",
            "categoryAttributeId": "05d394b2-3e75-4332-89d7-44c40dac3958",
            "name": "Size",
            "value": "XXS",
            "variants": []
        }
    ],
    "statusCode": 201
}

step 3 http://localhost:8081/api/v1/seller/product/add-variants
{
    "success": true,
    "message": "Variants added successfully",
    "data": null,
    "statusCode": 200
}

step 4 http://localhost:8081/api/v1/seller/product/upload-images

{
    "success": true,
    "message": "Media uploaded successfully",
    "data": {
        "productId": "94bab102-45c6-4db0-99f4-4fab766d2ebd",
        "coverImageUrl": "https://res.cloudinary.com/dbmcqwakw/image/upload/v1776709185/products/94bab102-45c6-4db0-99f4-4fab766d2ebd/cover/ca7gu9kutaoxxu9hsojz.png",
        "attributeMedia": {
            "Red": [
                "https://res.cloudinary.com/dbmcqwakw/image/upload/v1776709189/products/94bab102-45c6-4db0-99f4-4fab766d2ebd/Red/pveyr5bmy0louw1ywanb.png"
            ]
        }
    },
    "statusCode": 200
}

step 5 http://localhost:8081/api/v1/seller/product/add-tag
{
    "success": true,
    "message": "Tags added successfully",
    "data": null,
    "statusCode": 200
}

step 5 
http://localhost:8081/api/v1/seller/product/attach-brand?productId=94bab102-45c6-4db0-99f4-4fab766d2ebd&brandId=d237fc20-78a7-444f-88d7-00467539dd4d

{
    "success": true,
    "message": "Brand attached to product successfully",
    "data": null,
    "statusCode": 200
}