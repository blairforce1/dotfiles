Work in progress / notes - not managed at the moment

## Software Development Projects

### Work Items and Issues

All Work is sourced from issues within the GitHub project for the current repo.
Each issue has a unique ID and this should be used to identify the work wherever possible:
- branch names should be prefixed with the ID e.g. "issue/12345/issue-brief-title"
- PRs should have the Subject prefixed with the ID, e.g. "12345: The PR Subject Title"


### General

- When writing commit messages, NEVER auto-add your agent name as co-author
- Never manually modify any files that are marked as auto-generated
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- Prefer Vertical Slice code architecture and favour small, cohesive slices and ALWAYS avoid coupling between slices.
- Vertical slices should have a readme document describing what they are and, where possible, link back to any work item / issue tracking that prompted them.
- Every repo should have a docs folder. Within the docs folder should be a decisions folder. Lightweight Architecture Decision Records should be maintained for any decisions made.
- Commits should be small and frequent.
- Pull Requests should be small for faster review.
- Prefer multiple smaller PRs for the same feature rather than one large PR.

### Testing

- TestContainers should be used for integration testing.
- Mocking should be avoided.
- Integration testing should be generally preferred over unit testing. Unit tests should be for the more complex units.
- Prefer TUnit test framework for .net projects: `dotnet add package TUnit`.
- Tests should be categorized using the Category attribute. Categories should come from the Issue tags.
- Code Coverage metrics should be generated and tracked.
- Mutation testing should be used to help verify our code coverage using Stryker `dotnet tool install -g dotnet-stryker`
  Mutation test reports must be reviewed and new tests should be proposed for undetected mutations.
- Use property-based testing where applicable `dotnet add package FsCheck`.
- Mutation tests should have a "Mutation" category set AND the Explicit attribute so that mutation tests are only run on demand (dotnet test --treenode-filter "/*/*/*/*[Category=Mutation]").
- Property-based should have a "PropertyBased" category set AND the Explicit attribute so that property-based tests are only run on demand (dotnet test --treenode-filter "/*/*/*/*[Category=PropertyBased]").

### SBOMs

All libraries, where possible, should generate an SBOM.
Use the Microsoft sbom-tool (https://github.com/microsoft/sbom-tool) but also generate the SBOM when building using the SBOM targets.
SBOM Targets: `dotnet package add Microsoft.Sbom.Targets`
Then, add the following to the project file to enable it (but only for release builds):
```
<Choose>
  <When Condition="'$(Configuration)' == 'Release'">
    <PropertyGroup>
      <GenerateSBOM>true</GenerateSBOM>
    </PropertyGroup>
    <ItemGroup>
      <PackageReference 
          Include="Microsoft.Sbom.Targets" 
          Version="4.1.4" 
          PrivateAssets="All" />
    </ItemGroup>
  </When>
</Choose>
```
Note, the version in the snippet is for illustration only - use the current version.