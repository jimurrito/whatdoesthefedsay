# What Does the Fed(eral Reserve) say?
A simple Rest API that provides the current effective interest rate, as provided by the federal reserve here: [https://www.federalreserve.gov/releases/h15/](https://www.federalreserve.gov/releases/h15/)

The values for the API are updated as the federal reserve updates.

## How to use

From either a browser, or a Rest API client like Postman, goto [http://whatdoesthefedsay.com/rate](http://whatdoesthefedsay.com/rate).

This will provide a JSON body between 700-800 bytes in size.

```json
{ 
    "rate": "5.33", 
    "seed": 442595821, 
    "date": "2024-Jun-7", 
    "source": "https://www.federalreserve.gov/releases/h15/" 
}
```

There is no authentication or token needed to access.

> Keep in mind a few things as you use this:
> - The rate provided is from the last business day.
> - Effective rate is not the same as the average interest rate a loan will have. That rate will usually be higher.

## Any issues?
Open an issue on this repo!

# How I built this API for (almost) free
To build this API, I used a combination of Powershell, the Github Rest API, Github Pages.

## Powershell Script ([getrate.ps1](getrate.ps1))

1. Pulls the current current interest rate from the fed.
2. Parses HTML for the required values.
3. Used the Github API to create a branch on top of the Main branch to this repo.
4. Pushes the new rate into the [rate.html](rate.html) file.

This script runs as a cronjob using Powershell Core. However, it could also be ran from an Azure Function for the same cost. **Just so long as you keep it under 1,000,000 runs per month.**

## Github Pages
Pages feature in Github is a great way to host a blog. However, I'm using the static website functionality of pages to be the backend of my Rest API. 

This ensures I do not incurr any compute costs or scaling for the incomming requests. The last thing I want to do is expose a VM to the internet.

This also provides free DDOS attack protection, and any other protections that are native to Github.

## The Money Part
I used my domain provider IONOS to purchase the domain [whatdoesthefedsay.com](whatdoesthefedsay.com) for $10 a year. Feels like a good cost all-in-all.