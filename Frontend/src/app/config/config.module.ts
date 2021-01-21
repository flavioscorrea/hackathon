import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { PoModule } from '@po-ui/ng-components';
import { ConfigRoutingModule } from './config-routing.module';
import { RouterModule, Routes } from '@angular/router';
import { ConfigComponent } from './config.component';
import { FormsModule, ReactiveFormsModule } from '@angular/forms'

const routes: Routes = [
  { path: '', component: ConfigComponent },
];

@NgModule({
  declarations: [ConfigComponent],
  imports: [
    PoModule,
    FormsModule,
    CommonModule,
    RouterModule.forChild(routes),
    ConfigRoutingModule
  ]
})
export class ConfigModule { }