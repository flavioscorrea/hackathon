import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { ConfigComponent } from './config/config.component';
import { HomeComponent } from './home/home.component';

  const routes: Routes = [ 
  { path: 'config', component: ConfigComponent }, { path: 'home', component: HomeComponent } ];
  @NgModule({
    imports: [RouterModule.forRoot(routes, {useHash: true})],
    exports: [RouterModule]
  })
export class AppRoutingModule { }
